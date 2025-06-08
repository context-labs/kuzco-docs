#!/bin/bash

# 🔥 ULTIMATE AUTO-PERSISTENCE MULTI-GPU INFERENCE.NET INSTALLER 🔥
# Created by: Bokiko
# Description: Self-saving interactive installer with auto-boot capability

# Configuration file path
CONFIG_FILE="$HOME/.inference-mining-config.json"
SERVICE_NAME="inference-mining"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Colors for better UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_colored() {
    color=$1
    message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print banner
print_banner() {
    clear
    print_colored $CYAN "========================================"
    print_colored $CYAN "🔥 ULTIMATE INFERENCE.NET INSTALLER 🔥"
    print_colored $CYAN "    Auto-Persistence Mining Setup     "
    print_colored $CYAN "========================================"
    echo ""
}

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HOME/inference-installer.log"
}

# Function to save configuration
save_config() {
    local config_data="{
    \"timestamp\": \"$(date '+%Y-%m-%d %H:%M:%S')\",
    \"gpu_count\": $user_gpu_count,
    \"container_prefix\": \"$name_prefix\",
    \"worker_codes\": ["
    
    for i in $(seq 0 $((user_gpu_count-1))); do
        config_data="$config_data\"${worker_codes[$i]}\""
        if [ $i -lt $((user_gpu_count-1)) ]; then
            config_data="$config_data,"
        fi
    done
    
    config_data="$config_data],
    \"script_path\": \"$(realpath $0)\"
}"
    
    echo "$config_data" > "$CONFIG_FILE"
    log_message "Configuration saved to $CONFIG_FILE"
    print_colored $GREEN "✅ Configuration saved!"
}

# Function to load configuration
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 1
    fi
    
    # Parse JSON configuration
    user_gpu_count=$(jq -r '.gpu_count' "$CONFIG_FILE" 2>/dev/null)
    name_prefix=$(jq -r '.container_prefix' "$CONFIG_FILE" 2>/dev/null)
    
    # Load worker codes
    worker_codes=()
    for i in $(seq 0 $((user_gpu_count-1))); do
        code=$(jq -r ".worker_codes[$i]" "$CONFIG_FILE" 2>/dev/null)
        worker_codes+=("$code")
    done
    
    # Validate loaded config
    if [ "$user_gpu_count" = "null" ] || [ "$name_prefix" = "null" ] || [ ${#worker_codes[@]} -eq 0 ]; then
        return 1
    fi
    
    return 0
}

# Function to show existing configuration
show_existing_config() {
    local timestamp=$(jq -r '.timestamp' "$CONFIG_FILE" 2>/dev/null)
    
    print_colored $PURPLE "📋 EXISTING CONFIGURATION FOUND:"
    print_colored $PURPLE "================================"
    print_colored $BLUE "   Created: $timestamp"
    print_colored $BLUE "   GPUs: $user_gpu_count"
    print_colored $BLUE "   Prefix: $name_prefix"
    print_colored $BLUE "   Workers: ${#worker_codes[@]} configured"
    echo ""
    
    for i in $(seq 0 $((user_gpu_count-1))); do
        print_colored $BLUE "   GPU $i: $name_prefix-$i (${worker_codes[$i]:0:8}...)"
    done
    echo ""
}

# Function to ask about existing configuration
ask_use_existing_config() {
    show_existing_config
    
    print_colored $CYAN "❓ Use existing configuration? (y/n)"
    print_colored $YELLOW "   y = Deploy with saved settings"
    print_colored $YELLOW "   n = Start fresh interactive setup"
    read -p "   > " use_existing
    
    if [[ "$use_existing" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    print_colored $YELLOW "🔧 Checking system prerequisites..."
    
    # Check if jq exists (for JSON parsing)
    if ! command -v jq &> /dev/null; then
        print_colored $YELLOW "⚠️  Installing jq for configuration management..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        else
            print_colored $RED "❌ Please install 'jq' package manually"
            exit 1
        fi
    fi
    
    # Check if nvidia-smi exists
    if ! command -v nvidia-smi &> /dev/null; then
        print_colored $RED "❌ NVIDIA drivers not found! Please install NVIDIA drivers first."
        exit 1
    fi
    
    # Check if docker exists
    if ! command -v docker &> /dev/null; then
        print_colored $RED "❌ Docker not found! Please install Docker first."
        exit 1
    fi
    
    # Check docker permissions
    if ! docker ps &> /dev/null; then
        print_colored $RED "❌ Docker permission denied! Please add user to docker group:"
        print_colored $YELLOW "   sudo usermod -aG docker \$USER"
        print_colored $YELLOW "   Then logout and login again"
        exit 1
    fi
    
    print_colored $GREEN "✅ All prerequisites met!"
    echo ""
}

# Function to detect GPUs
detect_gpus() {
    print_colored $YELLOW "🔍 Detecting GPUs..."
    
    # Get GPU count and info
    detected_gpu_count=$(nvidia-smi --query-gpu=count --format=csv,noheader,nounits | head -1)
    
    if [ "$detected_gpu_count" -eq 0 ]; then
        print_colored $RED "❌ No GPUs detected!"
        exit 1
    fi
    
    print_colored $GREEN "✅ Detected $detected_gpu_count GPU(s):"
    echo ""
    
    # Display GPU information
    nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader | while IFS=, read -r index name memory; do
        print_colored $BLUE "   GPU $index: $name ($memory)"
    done
    
    echo ""
}

# Function to get user input for number of GPUs
get_gpu_count() {
    while true; do
        print_colored $CYAN "❓ How many GPUs do you want to use for mining?"
        print_colored $YELLOW "   (Enter a number between 1 and $detected_gpu_count): "
        read -p "   > " user_gpu_count
        
        # Validate input
        if [[ "$user_gpu_count" =~ ^[0-9]+$ ]] && [ "$user_gpu_count" -ge 1 ] && [ "$user_gpu_count" -le "$detected_gpu_count" ]; then
            break
        else
            print_colored $RED "❌ Invalid input! Please enter a number between 1 and $detected_gpu_count"
            echo ""
        fi
    done
    
    echo ""
    print_colored $GREEN "✅ Will setup $user_gpu_count GPU(s) for mining"
    echo ""
}

# Function to get worker codes
get_worker_codes() {
    print_colored $CYAN "🔑 Now we need worker codes for each GPU"
    print_colored $YELLOW "   Go to: https://devnet.inference.net/dashboard"
    print_colored $YELLOW "   1. Click 'Workers' tab"
    print_colored $YELLOW "   2. Create a worker for each GPU"
    print_colored $YELLOW "   3. Select 'Docker' deployment"
    print_colored $YELLOW "   4. Copy the code after '--code'"
    echo ""
    
    # Array to store worker codes
    worker_codes=()
    
    for i in $(seq 0 $((user_gpu_count-1))); do
        while true; do
            print_colored $CYAN "🎯 Enter worker code for GPU $i:"
            print_colored $YELLOW "   (Paste the code after '--code' from dashboard)"
            read -p "   > " worker_code
            
            # Basic validation (check if it looks like a UUID)
            if [[ "$worker_code" =~ ^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
                worker_codes+=("$worker_code")
                print_colored $GREEN "   ✅ Worker code for GPU $i saved!"
                echo ""
                break
            else
                print_colored $RED "   ❌ Invalid worker code format! Should be like: 793ed789-703d-4bff-a6f1-8cfde3289a79"
                echo ""
            fi
        done
    done
    
    print_colored $GREEN "✅ All worker codes collected!"
    echo ""
}

# Function to ask for custom names
get_container_names() {
    print_colored $CYAN "🏷️  Container Naming:"
    print_colored $YELLOW "   Do you want custom container names? (y/n)"
    read -p "   > " custom_names
    
    if [[ "$custom_names" =~ ^[Yy]$ ]]; then
        print_colored $CYAN "   Enter a prefix for container names (e.g., 'rig', 'miner', 'kuzco'):"
        read -p "   > " name_prefix
        
        if [ -z "$name_prefix" ]; then
            name_prefix="inference-gpu"
        fi
    else
        name_prefix="inference-gpu"
    fi
    
    print_colored $GREEN "✅ Will use prefix: $name_prefix"
    echo ""
}

# Function to show deployment summary
show_summary() {
    print_colored $PURPLE "📋 DEPLOYMENT SUMMARY:"
    print_colored $PURPLE "====================="
    print_colored $BLUE "   GPUs to use: $user_gpu_count"
    print_colored $BLUE "   Container prefix: $name_prefix"
    print_colored $BLUE "   Worker codes: ${#worker_codes[@]} codes collected"
    echo ""
    
    for i in $(seq 0 $((user_gpu_count-1))); do
        print_colored $BLUE "   GPU $i: $name_prefix-$i (${worker_codes[$i]:0:8}...)"
    done
    
    echo ""
    print_colored $CYAN "❓ Ready to deploy? (y/n)"
    read -p "   > " confirm_deploy
    
    if [[ ! "$confirm_deploy" =~ ^[Yy]$ ]]; then
        print_colored $YELLOW "⏹️  Deployment cancelled by user"
        exit 0
    fi
}

# Function to stop existing containers
stop_existing_containers() {
    print_colored $YELLOW "🛑 Stopping existing containers with prefix '$name_prefix'..."
    
    # Stop containers with the specified prefix
    existing_containers=$(docker ps -q --filter "name=$name_prefix" 2>/dev/null)
    if [ ! -z "$existing_containers" ]; then
        docker stop $existing_containers >/dev/null 2>&1
        docker rm $existing_containers >/dev/null 2>&1
        print_colored $GREEN "   ✅ Stopped existing containers"
    else
        print_colored $BLUE "   ℹ️  No existing containers found"
    fi
    echo ""
}

# Function to deploy containers
deploy_containers() {
    print_colored $CYAN "🚀 DEPLOYING CONTAINERS..."
    echo ""
    
    local failed_deployments=0
    
    # Deploy each GPU
    for i in $(seq 0 $((user_gpu_count-1))); do
        container_name="$name_prefix-$i"
        worker_code="${worker_codes[$i]}"
        
        print_colored $YELLOW "   🎯 Deploying GPU $i as '$container_name'..."
        
        # Run the container
        if docker run -d \
            --pull=always \
            --restart=always \
            --runtime=nvidia \
            --gpus "\"device=$i\"" \
            --name "$container_name" \
            --memory=6g \
            --cpus=2 \
            -v "$HOME/.inference-gpu$i:/root/.inference" \
            -e NVIDIA_VISIBLE_DEVICES=$i \
            inferencedevnet/amd64-nvidia-inference-node:latest \
            --code "$worker_code" > /dev/null 2>&1; then
            
            print_colored $GREEN "   ✅ GPU $i deployed successfully!"
            log_message "GPU $i ($container_name) deployed successfully"
        else
            print_colored $RED "   ❌ GPU $i deployment failed!"
            log_message "GPU $i ($container_name) deployment failed"
            ((failed_deployments++))
        fi
        
        sleep 2
    done
    
    echo ""
    
    if [ $failed_deployments -eq 0 ]; then
        print_colored $GREEN "🎉 All containers deployed successfully!"
    else
        print_colored $YELLOW "⚠️  $failed_deployments container(s) failed to deploy"
    fi
}

# Function to create systemd service for auto-start
create_autostart_service() {
    print_colored $CYAN "🔄 Setting up auto-start on boot..."
    
    local script_path=$(realpath "$0")
    
    # Create systemd service file
    sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Inference.net Multi-GPU Mining Auto-Start
After=docker.service nvidia-persistenced.service
Requires=docker.service
Wants=nvidia-persistenced.service

[Service]
Type=oneshot
User=$USER
Environment=HOME=$HOME
WorkingDirectory=$HOME
ExecStart=$script_path --auto-start
RemainAfterExit=true
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_colored $GREEN "   ✅ Auto-start service created and enabled!"
        log_message "Auto-start service created: $SERVICE_FILE"
    else
        print_colored $YELLOW "   ⚠️  Failed to create auto-start service (non-critical)"
    fi
    echo ""
}

# Function to show final status
show_final_status() {
    print_colored $GREEN "🎉 DEPLOYMENT COMPLETE!"
    echo ""
    
    print_colored $CYAN "📊 Container Status:"
    docker ps --filter "name=$name_prefix" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}" 2>/dev/null
    
    echo ""
    print_colored $CYAN "🎯 Monitoring Commands:"
    print_colored $YELLOW "   Real-time GPU monitoring: watch -n 1 nvidia-smi"
    print_colored $YELLOW "   Container stats: docker stats"
    print_colored $YELLOW "   Check logs: docker logs $name_prefix-0 -f"
    print_colored $YELLOW "   Rig monitor: ./monitor-rig.sh"
    
    echo ""
    print_colored $CYAN "🌐 Dashboard:"
    print_colored $YELLOW "   https://devnet.inference.net/dashboard"
    
    echo ""
    print_colored $CYAN "🔧 Management Commands:"
    print_colored $YELLOW "   Restart installer: $0"
    print_colored $YELLOW "   Stop all: docker stop \$(docker ps -q --filter 'name=$name_prefix')"
    print_colored $YELLOW "   View config: cat $CONFIG_FILE"
    print_colored $YELLOW "   Check service: sudo systemctl status $SERVICE_NAME"
    
    echo ""
    print_colored $GREEN "💰 Your mining rig will now auto-start on boot!"
    print_colored $GREEN "🔄 Reboot to test: sudo reboot"
    echo ""
}

# Function to create monitoring script
create_monitor_script() {
    print_colored $CYAN "📊 Creating monitoring script..."
    
cat > monitor-rig.sh << EOF
#!/bin/bash
# GPU Mining Rig Monitor Script - Generated by Ultimate Installer

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

CONFIG_FILE="$CONFIG_FILE"

clear
echo -e "\${CYAN}🔥 INFERENCE.NET RIG STATUS 🔥\${NC}"
echo -e "\${CYAN}==============================\${NC}"
echo ""

# Show configuration info
if [ -f "\$CONFIG_FILE" ]; then
    echo -e "\${PURPLE}📋 Configuration:\${NC}"
    echo "Created: \$(jq -r '.timestamp' "\$CONFIG_FILE" 2>/dev/null)"
    echo "GPUs: \$(jq -r '.gpu_count' "\$CONFIG_FILE" 2>/dev/null)"
    echo "Prefix: \$(jq -r '.container_prefix' "\$CONFIG_FILE" 2>/dev/null)"
    echo ""
fi

echo -e "\${YELLOW}📊 GPU Status:\${NC}"
nvidia-smi --query-gpu=index,name,temperature.gpu,power.draw,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits | head -$user_gpu_count

echo ""
echo -e "\${YELLOW}📦 Container Status:\${NC}"
docker ps --filter "name=$name_prefix" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"

echo ""
echo -e "\${YELLOW}💻 System Resources:\${NC}"
echo "CPU: \$(top -bn1 | grep "Cpu(s)" | awk '{print \$2}' | sed 's/%us,//')% usage"
echo "RAM: \$(free -h | awk '/^Mem:/ {print \$3 "/" \$2}')"
echo "Disk: \$(df -h / | awk 'NR==2 {print \$3 "/" \$2 " (" \$5 " used)"}')"

echo ""
echo -e "\${YELLOW}🔄 Auto-Start Status:\${NC}"
if systemctl is-enabled $SERVICE_NAME >/dev/null 2>&1; then
    echo -e "\${GREEN}✅ Auto-start: ENABLED\${NC}"
else
    echo -e "\${RED}❌ Auto-start: DISABLED\${NC}"
fi

echo ""
echo -e "\${CYAN}🌐 Dashboard: https://devnet.inference.net/dashboard\${NC}"
echo -e "\${CYAN}🔧 Restart: $script_path\${NC}"
echo ""
EOF

    chmod +x monitor-rig.sh
    print_colored $GREEN "   ✅ Monitor script created: ./monitor-rig.sh"
    echo ""
}

# Function to handle auto-start mode
handle_autostart() {
    log_message "Auto-start mode initiated"
    
    if load_config; then
        print_colored $CYAN "🔄 Auto-starting from saved configuration..."
        stop_existing_containers
        deploy_containers
        log_message "Auto-start deployment completed"
        print_colored $GREEN "✅ Auto-start deployment completed!"
    else
        log_message "Auto-start failed: No valid configuration found"
        print_colored $RED "❌ Auto-start failed: No valid configuration found"
        exit 1
    fi
}

# Main execution flow
main() {
    # Handle auto-start mode (called by systemd)
    if [ "$1" = "--auto-start" ]; then
        handle_autostart
        exit 0
    fi
    
    print_banner
    log_message "Interactive installer started"
    
    # Check system requirements
    check_prerequisites
    
    # Detect GPUs
    detect_gpus
    
    # Check if configuration exists
    if load_config; then
        if ask_use_existing_config; then
            print_colored $CYAN "🔄 Using existing configuration..."
            stop_existing_containers
            deploy_containers
            show_final_status
            exit 0
        else
            print_colored $YELLOW "🔄 Starting fresh setup..."
            echo ""
        fi
    fi
    
    # Interactive setup
    get_gpu_count
    get_worker_codes
    get_container_names
    
    # Show summary and confirm
    show_summary
    
    # Save configuration before deployment
    save_config
    
    # Deploy
    stop_existing_containers
    deploy_containers
    
    # Create auto-start service
    create_autostart_service
    
    # Create monitoring tools
    create_monitor_script
    
    # Show final status
    show_final_status
    
    log_message "Setup completed successfully"
}

# Error handling
set -e
trap 'print_colored $RED "❌ Script failed! Check the error above."; log_message "Script failed with error"; exit 1' ERR

# Run main function
main "$@"
