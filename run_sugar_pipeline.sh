#!/bin/bash
set -e

# -------------------------------
# 0. Parse args
# -------------------------------
DATASET_NAME=$1
REFINEMENT_TIME="short"   # μπορείς να αλλάξεις σε medium | long

if [ -z "$DATASET_NAME" ]; then
  echo "Usage: $0 DATASET_NAME"
  exit 1
fi

echo "======================================"
echo " Running SuGaR pipeline "
echo " Dataset: $DATASET_NAME"
echo " Refinement time: $REFINEMENT_TIME"
echo "======================================"

# -------------------------------
# 1. Prepare directories
# -------------------------------
echo "[*] STEP 1: Preparing directories..."
mkdir -p ~/SuGaR_Docker/cache
mkdir -p ~/SuGaR_Docker/outputs/$DATASET_NAME
sudo chown -R $(id -u):$(id -g) ~/SuGaR_Docker/outputs/$DATASET_NAME
chmod -R 775 ~/SuGaR_Docker/outputs/$DATASET_NAME

# -------------------------------
# 2. Build Docker image (if needed)
# -------------------------------
echo "[*] STEP 2: Building Docker image sugar-final (if not already built)..."
cd ~/SuGaR_Docker/SuGaR
sudo docker build -t sugar-final -f Dockerfile_final .


# -------------------------------
# 3. Run training (skip if already trained)
# -------------------------------
echo "[*] STEP 3: Training SuGaR on dataset=$DATASET_NAME..."


sudo docker run -it --rm --gpus all \
  -v "$HOME/SuGaR_Docker/data/$DATASET_NAME:/app/data" \
  -v "$HOME/SuGaR_Docker/outputs/$DATASET_NAME:/app/output" \
  --user $(id -u):$(id -g) \
  -v "$HOME/SuGaR_Docker/cache:/app/.cache" \
  -e XDG_CACHE_HOME=/app/.cache \
  -e TORCH_EXTENSIONS_DIR=/app/.cache/torch_extensions \
  -e HOME=/app \
  sugar-final \
  /app/run_with_xvfb.sh python train_full_pipeline.py \
    -s /app/data \
    -r dn_consistency \
    --refinement_time $REFINEMENT_TIME \
    --export_obj False
    
# --user $(id -u):$(id -g) \
# -------------------------------
# 4. Extract textured mesh
# -------------------------------
echo "[*] STEP 4: Extracting textured mesh..."
sudo docker run -it --rm --gpus all \
  -v "$HOME/SuGaR_Docker/data/$DATASET_NAME:/app/data" \
  -v "$HOME/SuGaR_Docker/outputs/$DATASET_NAME:/app/output" \
  -v "$HOME/SuGaR_Docker/cache:/app/.cache" \
  --user $(id -u):$(id -g) \
  -e XDG_CACHE_HOME=/app/.cache \
  -e TORCH_EXTENSIONS_DIR=/app/.cache/torch_extensions \
  -e HOME=/app \
  sugar-final bash -lc "\
    set -e
    REF=\$(find /app/output/refined/ -type f -name '2000.pt' | head -n1)

    if [ -z \"\$REF\" ]; then
      echo '[!] No refined checkpoint found, skipping mesh extraction.'
      exit 0
    fi

    echo 'Using refined checkpoint: '\$REF
    cp -r /app/sugar_utils /tmp/sugar_utils
    sed -i 's/RasterizeGLContext()/RasterizeCudaContext()/g' /tmp/sugar_utils/mesh_rasterization.py
    ln -sfn /app/output /tmp/output
    cd /tmp
    PYTHONPATH=/tmp:/app:/app/gaussian_splatting:\$PYTHONPATH \
      python -m extract_refined_mesh_with_texture \
        -s /app/data \
        -c /app/output/vanilla_gs/data \
        -m \"\$REF\" \
        -o /app/output/refined_mesh/data \
        --square_size 8
  "

# -------------------------------
# 5. Prepare viewer files
# -------------------------------
echo "[*] STEP 5: Preparing viewer..."
sudo docker run -it --rm -p 5173:5173 \
  -v "$HOME/SuGaR_Docker/outputs/$DATASET_NAME:/app/output" \
  sugar-final bash -lc '
    set -e
    PLY=$(ls /app/output/refined_ply/data/*.ply | head -n1 || true)
    OBJ=$(ls /app/output/refined_mesh/data/*.obj | head -n1 || true)
    PNG=$(ls /app/output/refined_mesh/data/*.png | head -n1 || true)

    if [ -z "$PLY" ] || [ -z "$OBJ" ] || [ -z "$PNG" ]; then
      echo "[!] Missing viewer files → check mesh extraction step."
      exit 0
    fi

    mkdir -p /app/sugar_viewer/public
    cp "$PLY" /app/sugar_viewer/public
    cp "$OBJ" /app/sugar_viewer/public
    cp "$PNG" /app/sugar_viewer/public

    PLY_BASE=$(basename "$PLY")
    OBJ_BASE=$(basename "$OBJ")
    PNG_BASE=$(basename "$PNG")

    cat > /app/sugar_viewer/src/scene_to_load.json <<EOF
{
  "ply_path": "public/$PLY_BASE",
  "obj_path": "public/$OBJ_BASE",
  "png_path": "public/$PNG_BASE"
}
EOF

    cd /app/sugar_viewer && npm run dev -- --host 0.0.0.0 --port 5173
  '

echo "======================================"
echo " DONE! Open http://localhost:5173 to view results."

