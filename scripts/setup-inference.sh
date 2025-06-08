#!/bin/bash

# Text colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${BLUE}[Inference.net Setup]:${NC} $1"
}

print_success() {
    echo -e "${GREEN}[Success]:${NC} $1"
}

print_error() {
    echo -e "${RED}[Error]:${NC} $1"
}

# Function definitions
print_gpu_info() {
    echo ""
    print_message "GPU Information:"
    echo "----------------------------------------"
    nvidia-smi --query-gpu=index,gpu_name,memory.total,memory.free,temperature.gpu,power.draw,utilization.gpu --format=csv,noheader | while IFS="," read -r id name total_mem free_mem temp power util; do
        echo "GPU $id:"
        echo "  Name:          $name"
        echo "  Total Memory:  $total_mem"
        echo "  Free Memory:   $free_mem"
        echo "  Temperature:   $temp"
        echo "  Power Usage:   $power"
        echo "  Utilization:   $util"
        echo "----------------------------------------"
    done
}

check_gpu_health() {
    local gpu_index=$1
    local temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i $gpu_index)
    local util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i $gpu_index)
    local memory_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits -i $gpu_index)

    if [ $temp -gt 80 ]; then
        print_error "Warning: GPU $gpu_index temperature is high ($temp°C)"
        return 1
    fi

    if [ $util -gt 50 ]; then
        print_error "Warning: GPU $gpu_index is already under significant load ($util%)"
        return 1
    fi

    if [ $memory_used -gt 1000 ]; then
        print_error "Warning: GPU $gpu_index has significant memory usage (${memory_used}MB)"
        return 1
    fi

    return 0
}

verify_requirements() {
    # Check if nvidia-smi is available
    if ! command -v nvidia-smi &> /dev/null; then
        print_message "NVIDIA drivers not found. Installing NVIDIA drivers..."

        # Install python3-pip and click package
        print_message "Installing Python dependencies..."
        sudo apt update
        sudo apt install -y python3-pip python3-click

        # Install ubuntu-drivers-common if not present
        if ! command -v ubuntu-drivers &> /dev/null; then
            print_message "Installing ubuntu-drivers-common..."
            sudo apt install -y ubuntu-drivers-common
        fi

        # Show available drivers
        print_message "Available NVIDIA drivers for your system:"
        ubuntu-drivers devices

        # Ask for installation method
        echo ""
        echo "Choose driver installation method:"
        echo "1) Automatic installation (recommended)"
        echo "2) Manual installation (specify driver version)"
        read -p "Enter your choice (1 or 2): " DRIVER_CHOICE

        case $DRIVER_CHOICE in
            1)
                print_message "Installing NVIDIA drivers automatically..."
                sudo ubuntu-drivers autoinstall
                ;;
            2)
                echo ""
                read -p "Enter the driver version number (e.g., 525): " DRIVER_VERSION
                if [ -z "$DRIVER_VERSION" ]; then
                    print_error "Driver version cannot be empty"
                    exit 1
                fi
                print_message "Installing NVIDIA driver version $DRIVER_VERSION..."
                sudo apt install -y nvidia-driver-$DRIVER_VERSION
                ;;
            *)
                print_error "Invalid choice. Exiting..."
                exit 1
                ;;
        esac

        print_message "NVIDIA drivers installation completed."
    else
        print_success "NVIDIA drivers are already installed!"
        # Check NVIDIA driver version
        NVIDIA_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n 1)
        print_message "Current NVIDIA driver version: $NVIDIA_VERSION"
    fi

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_message "Docker not found. Installing Docker..."

        # Update package list
        sudo apt update

        # Install prerequisites
        print_message "Installing prerequisites..."
        sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

        # Add Docker's official GPG key
        print_message "Adding Docker repository..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        # Update package list again
        sudo apt update

        # Install Docker
        print_message "Installing Docker..."
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

        # Start and enable Docker service
        print_message "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker

        print_success "Docker installed successfully!"
    else
        print_success "Docker is already installed!"
    fi

    # Check Docker service status
    if ! systemctl is-active --quiet docker; then
        print_error "Docker service is not running. Starting Docker service..."
        sudo systemctl start docker
    fi

    # Install NVIDIA Container Toolkit if not present
    if ! dpkg -l | grep -q nvidia-container-toolkit; then
        print_message "Installing NVIDIA Container Toolkit..."
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
        sudo apt update
        sudo apt install -y nvidia-docker2
        sudo systemctl restart docker
        print_success "NVIDIA Container Toolkit installed successfully!"
    else
        print_success "NVIDIA Container Toolkit is already installed!"
    fi

    # Check if user has Docker permissions
    if ! docker info &> /dev/null; then
        print_message "Adding current user to docker group..."
        sudo usermod -aG docker $USER
        print_message "Please log out and log back in for changes to take effect."
        print_message "After logging back in, run this script again."
        exit 1
    fi
}

# Start of main script
clear
echo "================================================"
print_message "Welcome to the Inference.net Setup Script!"
echo "================================================"

# Verify system requirements
verify_requirements

# Step 1: Update system
print_message "Updating system packages..."
sudo apt update

# Get worker code upfront
print_message "Please enter your worker code from the dashboard"
read -p "Worker code: " WORKER_CODE
if [ -z "$WORKER_CODE" ]; then
    print_error "Worker code cannot be empty"
    exit 1
fi

# Step 6: Configure and run Docker container(s)
print_message "Checking available GPUs..."
GPU_COUNT=$(nvidia-smi --query-gpu=gpu_name --format=csv,noheader | wc -l)
if [ "$GPU_COUNT" -lt 1 ]; then
    print_error "No GPUs detected. Please check your NVIDIA driver installation."
    exit 1
fi

print_message "Found $GPU_COUNT GPU(s) in your system"
print_gpu_info

echo ""
echo "Choose your deployment option:"
echo "1) Run single container using all GPUs"
echo "2) Run separate container for each GPU"
echo "3) Run containers on specific number of GPUs"
read -p "Enter your choice (1, 2, or 3): " CONTAINER_CHOICE

case $CONTAINER_CHOICE in
    1)
        print_message "Starting single container with all GPUs..."
        # Check health of all GPUs
        for i in $(seq 0 $(($GPU_COUNT-1))); do
            if ! check_gpu_health $i; then
                read -p "GPU $i shows warning signs. Continue anyway? (y/n): " CONTINUE
                if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
                    print_message "Aborting deployment. Please check GPU status."
                    exit 1
                fi
            fi
        done

        docker run -d \
            --pull=always \
            --restart=always \
            --runtime=nvidia \
            --gpus all \
            --name inference-all-gpus \
            -v ~/.inference:/root/.inference \
            inferencedevnet/amd64-nvidia-inference-node:latest \
            --code $WORKER_CODE
        ;;
    2)
        print_message "Starting deployment for $GPU_COUNT GPUs..."

        for i in $(seq 0 $(($GPU_COUNT-1))); do
            if ! check_gpu_health $i; then
                read -p "GPU $i shows warning signs. Continue anyway? (y/n): " CONTINUE
                if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
                    print_message "Skipping GPU $i"
                    continue
                fi
            fi

            print_message "Starting container for GPU $i..."
            docker run -d \
                --name inference-gpu-$i \
                --pull=always \
                --restart=always \
                --runtime=nvidia \
                --gpus device=$i \
                -v ~/.inference_gpu_$i:/root/.inference \
                inferencedevnet/amd64-nvidia-inference-node:latest \
                --code $WORKER_CODE

            print_success "Container for GPU $i started successfully!"
        done
        ;;
    3)
        while true; do
            read -p "How many GPUs would you like to use? (1-$GPU_COUNT): " DESIRED_GPU_COUNT
            if ! [[ "$DESIRED_GPU_COUNT" =~ ^[0-9]+$ ]] || [ "$DESIRED_GPU_COUNT" -lt 1 ] || [ "$DESIRED_GPU_COUNT" -gt "$GPU_COUNT" ]; then
                print_error "Please enter a valid number between 1 and $GPU_COUNT"
                continue
            fi
            break
        done

        echo ""
        print_message "Available GPUs:"
        print_gpu_info

        # Start containers for the specified number of GPUs
        for i in $(seq 0 $(($DESIRED_GPU_COUNT-1))); do
            if ! check_gpu_health $i; then
                read -p "GPU $i shows warning signs. Continue anyway? (y/n): " CONTINUE
                if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
                    print_message "Skipping GPU $i"
                    continue
                fi
            fi

            print_message "Starting container for GPU $i..."
            docker run -d \
                --name inference-gpu-$i \
                --pull=always \
                --restart=always \
                --runtime=nvidia \
                --gpus device=$i \
                -v ~/.inference_gpu_$i:/root/.inference \
                inferencedevnet/amd64-nvidia-inference-node:latest \
                --code $WORKER_CODE

            print_success "Container for GPU $i started successfully!"
        done
        ;;
    *)
        print_error "Invalid choice. Exiting..."
        exit 1
        ;;
esac

# Final message with container status
echo ""
echo "================================================"
print_success "Setup completed! Your node(s) should start shortly."
print_message "Checking container status..."
docker ps --filter "name=inference-"
echo ""
print_message "To view your node's logs, use one of these commands:"
print_message "- List all containers:    docker ps"
print_message "- View specific logs:     docker logs -f <container_name>"
if [ "$CONTAINER_CHOICE" = "1" ]; then
    print_message "Your container name is: inference-all-gpus"
elif [ "$CONTAINER_CHOICE" = "2" ]; then
    print_message "Your containers are named: inference-gpu-0 through inference-gpu-$(($GPU_COUNT-1))"
else
    print_message "Your containers are named: inference-gpu-X (where X is your selected GPU index)"
fi
echo "================================================"

# Recommend system restart
echo ""
print_message "It's recommended to restart your system now."
read -p "Would you like to restart now? (y/n): " RESTART
if [[ $RESTART =~ ^[Yy]$ ]]; then
    print_message "Restarting system..."
    reboot
fi