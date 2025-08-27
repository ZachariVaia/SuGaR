# SuGaR\_Docker — Quick Start Guide

This README provides clear instructions on how to set up the environment, build the Docker image, and run the SuGaR pipeline.

## Requirements

* **Git**
* **Docker** (with NVIDIA drivers + `nvidia-container-toolkit` if you want GPU support)

Check installations:

```bash
git --version
docker --version
```

---

## 1) Clone the Repository

Create a folder in your **home directory** called `SuGaR_Docker`, clone the repository, and prepare the outputs folder:

```bash
cd ~
mkdir -p SuGaR_Docker
cd ~/SuGaR_Docker

mkdir -p outputs
> The `outputs/` folder will store all pipeline results.



git clone https://github.com/ZachariVaia/SuGaR.git
cd SuGaR
```

---

## 2) Build the Docker Image

From inside the `SuGaR` folder, build the Docker image:

```bash
docker build -t sugar-final -f Dockerfile_final .
```

* `-t sugar-final`: assigns a name (tag) to the image.
* `-f Dockerfile_final`: specifies the correct Dockerfile.
* `.`: sets the build context to the current folder.

---

## 3) Run the Pipeline

You can run the pipeline either inside Docker (recommended) or directly on your host if all dependencies are installed.



### Run directly on host 

```bash
bash run_sugar_pipeline.sh
```

---

## 4) Output Location

All results are stored in:

```
SuGaR_Docker/outputs/
```

---

## Troubleshooting

* **Wrong build command**: make sure you run

  ```bash
  docker build -t sugar-final -f Dockerfile_final .
  ```
* **Permission denied for Docker**: run `sudo usermod -aG docker $USER` and re-login or reboot.
* **No results appear**: check that you mounted the repo correctly with `-v "$(pwd)":/workspace`.
* **GPU not used**: ensure you have NVIDIA drivers + `nvidia-container-toolkit` and add `--gpus all` when running.

---

## Quick Commands

```bash
# Clone + setup
cd ~ && mkdir -p SuGaR_Docker && cd ~/SuGaR_Docker \
    && mkdir -p outputs  && git clone https://github.com/ZachariVaia/SuGaR.git \
    && cd SuGaR




# Build image
docker build -t sugar-final -f Dockerfile_final .

# Run Pipeline
./run_sugar_pipeline.sh dataset_name (eg bonsai)
```

---

## Done!

You are now ready to use the SuGaR pipeline inside Docker. 🚀
