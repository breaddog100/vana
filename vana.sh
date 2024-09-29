#!/bin/bash

# 设置版本号
current_version=20240929007

update_script() {
    # 指定URL
    update_url="https://raw.githubusercontent.com/breaddog100/vana/main/vana.sh"
    file_name=$(basename "$update_url")

    # 下载脚本文件
    tmp=$(date +%s)
    timeout 10s curl -s -o "$HOME/$tmp" -H "Cache-Control: no-cache" "$update_url?$tmp"
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        echo "命令超时"
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        echo "下载失败"
        return 1
    fi

    # 检查是否有新版本可用
    latest_version=$(grep -oP 'current_version=([0-9]+)' $HOME/$tmp | sed -n 's/.*=//p')

    if [[ "$latest_version" -gt "$current_version" ]]; then
        clear
        echo ""
        # 提示需要更新脚本
        printf "\033[31m脚本有新版本可用！当前版本：%s，最新版本：%s\033[0m\n" "$current_version" "$latest_version"
        echo "正在更新..."
        sleep 3
        mv $HOME/$tmp $HOME/$file_name
        chmod +x $HOME/$file_name
        exec "$HOME/$file_name"
    else
        # 脚本是最新的
        rm -f $tmp
    fi

}

# 部署环境
function install_env() {

    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y curl wget jq make gcc nano git software-properties-common

    # 安装 nvm
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    fi

    # 加载 nvm
    export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # 安装 Node.js 和 npm
    nvm install 18
    nvm use 18

    node -v
    npm -v

    # 安装 Python
    sudo add-apt-repository ppa:deadsnakes/ppa -y
    sudo apt update
    sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip

    curl -sSL https://install.python-poetry.org | python3 -
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> $HOME/.bashrc
    source $HOME/.bashrc
    python3.11 --version

    # 安装 Yarn
    npm install -g yarn

    # Clone GPT 代码
    git clone https://github.com/vana-com/vana-dlp-chatgpt.git
    cd $HOME/vana-dlp-chatgpt/
    cp .env.example .env

    # 配置环境
    python3.11 -m venv vana_gpt_env
    source vana_gpt_env/bin/activate
    pip install --upgrade pip
    pip install poetry
    pip install python-dotenv
    poetry install
    pip install vana

    # Clone 合约代码
    cd $HOME
    git clone https://github.com/Josephtran102/vana-dlp-smart-contracts
    cd vana-dlp-smart-contracts
    yarn install
    cp .env.example .env

    echo "部署完成..."
}

# 创建钱包
function create_wallet(){

    # Coldkey：质押使用
    # Hotkey：节点提交分数使用
    cd $HOME/vana-dlp-chatgpt
    source vana_gpt_env/bin/activate
    WALLET_NAME=default
    echo "程序会分别生成Coldkey（质押使用）和Hotkey（节点提交分数使用）两个钱包。使用默认名称为default即可"
    echo "密码要用字母和数字，请保存coldkey和hotkey的所有信息，除了密码部分需要输入，其他直接回车即可。"
    vanacli wallet create --wallet.name $WALLET_NAME --wallet.hotkey $WALLET_NAME

    echo "下面会分别导出2个钱包的私钥，名称使用默认default（回车即可），第一次导出coldkey（回车即可），第二次"
    echo "导出hotkey，在第二次选择时切记输入hotkey。将秘钥导入狐狸钱包后使用地址领水。"
    # 导出cold key私钥
    vanacli wallet export_private_key
    # 导出hot key私钥
    vanacli wallet export_private_key --wallet.hotkey $WALLET_NAME
}

# 部署合约
function contract_creation() {
    echo "1，请将上一步中的coldkey钱包的私钥准备好"
    echo "2，请将上一步中coldkey钱包的私钥导入狐狸钱包，并获取到钱包地址"
    echo "3，使用改地址到https://faucet.vana.org/领水"
    echo "部署结束请到：https://satori.vanascan.io/address通过钱包地址或tx hash查询"
    printf "\033[31m请确保钱包中有水，否则部署合约会失败。\033[0m\n"

    read -p "请输入coldkey钱包私钥: " DEPLOYER_PRIVATE_KEY
    read -p "请输入coldkey钱包地址: " OWNER_ADDRESS
    read -p "请输入DLP名称(如DLP-xxx): " DLP_NAME
    read -p "请输入DLP Token名称(如DLP-T-xxx): " DLP_TOKEN_NAME
    read -p "请输入DLP代币代码(如DLP-C-xxx): " DLP_TOKEN_SYMBOL

    cd $HOME/vana-dlp-chatgpt/
    source vana_gpt_env/bin/activate
    ./keygen.sh

    cd $HOME/vana-dlp-smart-contracts/
    sed -i "s/^DEPLOYER_PRIVATE_KEY=.*$/DEPLOYER_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY/" .env
    sed -i "s/^OWNER_ADDRESS=.*$/OWNER_ADDRESS=$OWNER_ADDRESS/" .env
    sed -i "s/^DLP_NAME=.*$/DLP_NAME=$DLP_NAME/" .env
    sed -i "s/^DLP_TOKEN_NAME=.*$/DLP_TOKEN_NAME=$DLP_TOKEN_NAME/" .env
    sed -i "s/^DLP_TOKEN_SYMBOL=.*$/DLP_TOKEN_SYMBOL=$DLP_TOKEN_SYMBOL/" .env

    # 需要有水
    # npx hardhat deploy --network satori --tags DLPDeploy --gasprice 1200000000
    npx hardhat deploy --network moksha --tags DLPDeploy

}

# 创建验证者
function create_validator(){

    echo "有兄弟部署后会出现无法调用合约的错误，目前我在解决，如果你解决了也感谢能指教一下，可以在电报群里找到我"
    echo "另外部署验证者之前要先注册Openai 的 API 接口，没错，是chatgpt的接口，需要先去申请。"
    read -r -p "确认开始部署[Y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "开始部署验证者..."
            cd $HOME/vana-dlp-chatgpt/
            source vana_gpt_env/bin/activate

            read -p "Hotkey钱包地址: " HOTKEY_ADDRESS
            OD_CHAIN_NETWORK=moksha
            OD_CHAIN_NETWORK_ENDPOINT=https://rpc.moksha.vana.org
            read -p "去注册个 OpenAI API（https://platform.openai.com/api-keys）: " OPENAI_API_KEY
            read -p "DLP POOL 地址（上一步成功日志中的DataLiquidityPool地址）: " DLP_MOKSHA_CONTRACT
            read -p "DLP Token 地址（上一步成功日志中的DataLiquidityPoolToken地址）: " DLP_TOKEN_MOKSHA_CONTRACT

            # 定义文件路径
            FILE_PATH="$HOME/vana-dlp-chatgpt/public_key_base64.asc"

            # 判断文件是否存在
            if [ -f "$FILE_PATH" ]; then
                # 文件存在，读取内容并赋值给变量
                PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=$(cat "$FILE_PATH")
            else
                # 文件不存在，进入指定目录并运行命令
                ./keygen.sh
                PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=$(cat "$FILE_PATH")
            fi

            echo "质押代币，确认钱包有水"
            # 质押代币
            vanacli dlp register_validator --stake_amount 10
            vanacli dlp approve_validator --validator_address="$HOTKEY_ADDRESS"

            echo "配置环境"
            # 修改.env文件
            sed -i "s/^OD_CHAIN_NETWORK=.*$/OD_CHAIN_NETWORK=$OD_CHAIN_NETWORK/" .env
            sed -i "s/^OPENAI_API_KEY=.*$/OPENAI_API_KEY=$OPENAI_API_KEY/" .env
            sed -i "s|^OD_CHAIN_NETWORK_ENDPOINT=.*$|OD_CHAIN_NETWORK_ENDPOINT=$OD_CHAIN_NETWORK_ENDPOINT|" .env
            sed -i "s/^DLP_MOKSHA_CONTRACT=.*$/DLP_MOKSHA_CONTRACT=$DLP_MOKSHA_CONTRACT/" .env
            sed -i "s/^DLP_TOKEN_MOKSHA_CONTRACT=.*$/DLP_TOKEN_MOKSHA_CONTRACT=$DLP_TOKEN_MOKSHA_CONTRACT/" .env
            sed -i "s/^PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=.*$/PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=$PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64/" .env

            # 运行验证者
            sudo tee /etc/systemd/system/vana-validator.service > /dev/null <<EOF
[Unit]
Description=Vana Validator Service
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/vana-dlp-chatgpt
Environment="PATH=$HOME/vana-dlp-chatgpt/vana_gpt_env/bin"
Environment="PYTHONPATH=$HOME/vana-dlp-chatgpt"
ExecStart=$HOME/.local/bin/poetry run python -m chatgpt.nodes.validator
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

            sudo systemctl daemon-reload
            sudo systemctl enable vana-validator
            sudo systemctl start vana-validator

            #poetry run python -m chatgpt.nodes.validator
            echo "验证者部署完成。"
            ;;
        *)
            echo "好的，等等再说吧。"
            ;;
    esac

}

# 查看日志
function view_logs(){
	sudo journalctl -u vana-validator.service -f --no-hostname -o cat
}

# 停止节点
function stop_node(){
	sudo systemctl stop vana-validator
	echo "quil 节点已停止"
}

# 启动节点
function start_node(){
	sudo systemctl start vana-validator
	echo "quil 节点已启动"
}

# 卸载节点
function uninstall_node() {
    echo "确定要卸载验证节点吗？[Y/N]"
    read -r -p "请确认: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            echo "开始卸载验证节点..."
            rm -rf $HOME/.vana $HOME/.yarn $HOME/vana-dlp-chatgpt $HOME/vana-dlp-smart-contracts
            echo "验证节点卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 菜单
function main_menu() {
    while true; do
        clear
        echo "======================= Vana 一键部署脚本======================="
        echo "当前版本：$current_version"
        echo "沟通电报群：https://t.me/lumaogogogo"
        echo "推荐配置：2C8G50G"
        echo "请选择要执行的操作:"
        echo "1. 部署环境 install_env"
        echo "2. 创建钱包 create_wallet"
        echo "3. 部署合约 contract_creation"
        echo "4. 创建验证者 create_validator"
        echo "5. 验证者日志 view_logs"
        echo "6. 停止验证者 stop_node"
        echo "7. 启动验证者 start_node"
        echo "1618. 卸载节点 uninstall_node"
        echo "0. 退出脚本 exit"
        read -p "请输入选项: " OPTION
    
        case $OPTION in
        1) install_env ;;
        2) create_wallet ;;
        3) contract_creation ;;
        4) create_validator ;;
        5) view_logs ;;
        6) stop_node ;;
        7) start_node ;;
        1618) uninstall_node ;;
        0) echo "退出脚本。"; exit 0 ;;
        *) echo "无效选项，请重新输入。"; sleep 3 ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 检查更新
update_script

# 运行菜单
main_menu