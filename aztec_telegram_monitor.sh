#!/bin/bash

# Automated installation script for Aztec Node Telegram Monitor
# Run with: source <(curl -s https://raw.githubusercontent.com/yourusername/yourrepo/main/aztec_telegram_monitor.sh)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install with apt or yum
install_package() {
    if command_exists apt-get; then
        apt-get install -y "$1"
    elif command_exists yum; then
        yum install -y "$1"
    elif command_exists dnf; then
        dnf install -y "$1"
    else
        echo -e "${RED}Error: Could not detect package manager (apt-get/yum/dnf)${NC}"
        return 1
    fi
}

# Function to create Python virtual environment
create_venv() {
    echo -e "${YELLOW}Creating Python virtual environment...${NC}"
    if ! python3 -m venv /opt/aztec-telegram-monitor/venv; then
        echo -e "${RED}Error: Failed to create virtual environment${NC}"
        echo -e "${YELLOW}Installing python3-venv package...${NC}"
        install_package python3-venv || return 1
        python3 -m venv /opt/aztec-telegram-monitor/venv || return 1
    fi
    return 0
}

# Function to install bot
install_bot() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error: This script must be run as root${NC}"
        return 1
    fi

    # Install system dependencies
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    install_package python3 || return 1
    install_package python3-pip || return 1

    # Create directory structure
    mkdir -p /opt/aztec-telegram-monitor
    cd /opt/aztec-telegram-monitor || return 1

    # Create virtual environment
    create_venv || return 1

    # Install Python packages in virtual environment
    echo -e "${YELLOW}Installing Python packages in virtual environment...${NC}"
    /opt/aztec-telegram-monitor/venv/bin/pip install python-telegram-bot || return 1

    # Get bot token
    echo -e "${GREEN}Telegram Bot Setup${NC}"
    read -p "Enter your Telegram Bot Token (from @BotFather): " BOT_TOKEN

    if [ -z "$BOT_TOKEN" ]; then
        echo -e "${RED}Error: Bot token cannot be empty${NC}"
        return 1
    fi

    # Create bot script
    echo -e "${YELLOW}Creating bot script...${NC}"
    cat > /opt/aztec-telegram-monitor/bot.py <<EOF
#!/usr/bin/env python3
from telegram import Update
from telegram.ext import ApplicationBuilder, CommandHandler, ContextTypes
import subprocess

BOT_TOKEN = '$BOT_TOKEN'

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("👋 Welcome to Aztec Node Monitor!\\nUse /status to check node status or /logs to view recent logs")

async def status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        result = subprocess.run(["systemctl", "is-active", "aztec-node"], capture_output=True, text=True)
        status = result.stdout.strip()
        if status == "active":
            await update.message.reply_text("✅ Aztec Node is running.")
        else:
            await update.message.reply_text(f"❌ Aztec Node is NOT running. Status: {status}")
    except Exception as e:
        await update.message.reply_text(f"⚠️ Error checking status: {e}")

async def logs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        result = subprocess.run(["journalctl", "-u", "aztec-node", "-n", "10", "--no-pager"], capture_output=True, text=True)
        logs = result.stdout.strip()
        await update.message.reply_text(f"📜 Latest 10 Log Entries:\\n\\n{logs[:4000]}")
    except Exception as e:
        await update.message.reply_text(f"⚠️ Error retrieving logs: {e}")

def main():
    app = ApplicationBuilder().token(BOT_TOKEN).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("status", status))
    app.add_handler(CommandHandler("logs", logs))
    app.run_polling()

if __name__ == "__main__":
    main()
EOF

    # Make script executable
    chmod +x /opt/aztec-telegram-monitor/bot.py

    # Create systemd service
    echo -e "${YELLOW}Creating systemd service...${NC}"
    cat > /etc/systemd/system/aztec-telegram-monitor.service <<EOF
[Unit]
Description=Aztec Node Telegram Monitor
After=network.target

[Service]
User=root
WorkingDirectory=/opt/aztec-telegram-monitor
ExecStart=/opt/aztec-telegram-monitor/venv/bin/python /opt/aztec-telegram-monitor/bot.py
Restart=always
RestartSec=30
Environment=PATH=/opt/aztec-telegram-monitor/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable aztec-telegram-monitor
    systemctl start aztec-telegram-monitor

    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo -e "The Telegram bot is now running as a systemd service."
    echo -e "You can check its status with: ${YELLOW}systemctl status aztec-telegram-monitor${NC}"
    echo -e "To stop it: ${YELLOW}systemctl stop aztec-telegram-monitor${NC}"
    echo -e "To view logs: ${YELLOW}journalctl -u aztec-telegram-monitor -f${NC}"
    return 0
}

# Function to uninstall bot
uninstall_bot() {
    echo -e "${YELLOW}Uninstalling Aztec Telegram Monitor...${NC}"
    
    # Stop and disable service
    if systemctl is-active --quiet aztec-telegram-monitor; then
        systemctl stop aztec-telegram-monitor
    fi
    
    if systemctl is-enabled --quiet aztec-telegram-monitor; then
        systemctl disable aztec-telegram-monitor
    fi
    
    # Remove files
    rm -f /etc/systemd/system/aztec-telegram-monitor.service
    rm -rf /opt/aztec-telegram-monitor
    systemctl daemon-reload
    
    echo -e "${GREEN}Uninstallation completed successfully!${NC}"
    return 0
}

# Main menu
if [[ $# -eq 0 ]]; then
    echo -e "${GREEN}Aztec Node Telegram Monitor Setup${NC}"
    echo "1. Install"
    echo "2. Uninstall"
    echo "3. Exit"
    read -p "Choose an option (1-3): " choice

    case $choice in
        1) install_bot ;;
        2) uninstall_bot ;;
        3) exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; exit 1 ;;
    esac
else
    case $1 in
        install) install_bot ;;
        uninstall) uninstall_bot ;;
        *) echo -e "${RED}Usage: $0 [install|uninstall]${NC}"; exit 1 ;;
    esac
fi
