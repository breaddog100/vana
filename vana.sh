#!/bin/bash

# 设置版本号
current_version=20240925004

update_script() {
    # 指定URL
    update_url="https://raw.githubusercontent.com/breaddog100/wana/main/wana.sh"
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

# 部署节点
function install_node() {

    read -p "钱包名称: " WALLET_NAME

    sudo apt update
    sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git python3-poetry

    git clone https://github.com/vana-com/vana-dlp-chatgpt.git
    cd $HOME/vana-dlp-chatgpt/
    cp .env.example .env

    cd $HOME/
    curl https://pyenv.run | bash
    echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> .bashrc
    echo 'eval "$(pyenv init --path)"' >> .bashrc
    echo 'eval "$(pyenv init -)"' >> .bashrc
    echo 'eval "$(pyenv virtualenv-init -)"' >> .bashrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> .bashrc
    source .bashrc
    pyenv install 3.11.4

    cd $HOME/vana-dlp-chatgpt
    pyenv local 3.11.4
    python --version

    sed -i '/\[tool.poetry.group.dev.dependencies\]/,/^$/ s/^[^#]/#&/' pyproject.toml

    poetry env use $(pyenv which python)

    cd $HOME
    pyenv global 3.11.4
    pip install --upgrade poetry
    cd vana-dlp-chatgpt
    rm poetry.lock
    poetry lock

    poetry install
    pip install vana

    cd $HOME
    git clone https://github.com/vana-com/vana-dlp-smart-contracts.git 
    cd vana-dlp-smart-contracts

    # 安装yarn
    sudo apt remove cmdtest
    curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
    sudo apt install -y nodejs
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt update && sudo apt install yarn
    yarn --version

    # 升级node
    curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt install -y nodejs
    node -v

    yarn install
    cp .env.example .env

    cd $HOME/vana-dlp-chatgpt
    echo "钱包密码要用字母和数字，请保存coldkey和hotkey的相关信息："
    ./vanacli wallet create --wallet.name $WALLET_NAME --wallet.hotkey $WALLET_NAME
    echo "下面是钱包对应私钥，请记录并保存，后续会用到："
    ./vanacli wallet export_private_key
    ./keygen.sh

    echo "部署完成..."
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
    read -p "请输入DLP代码(如DLP-C-xxx): " DLP_TOKEN_SYMBOL

    cd $HOME/vana-dlp-smart-contracts/
    sed -i 's/^DEPLOYER_PRIVATE_KEY=.*$/DEPLOYER_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY/' .env
    sed -i 's/^OWNER_ADDRESS=.*$/OWNER_ADDRESS=$OWNER_ADDRESS/' .env
    sed -i 's/^DLP_NAME=.*$/DLP_NAME=$DLP_NAME/' .env
    sed -i 's/^DLP_TOKEN_NAME=.*$/DLP_TOKEN_NAME=$DLP_TOKEN_NAME/' .env
    sed -i 's/^DLP_TOKEN_SYMBOL=.*$/DLP_TOKEN_SYMBOL=$DLP_TOKEN_SYMBOL/' .env

    # 需要有水
    npx hardhat deploy --network satori --tags DLPDeploy --gasprice 1200000000
    echo "如果出现类似Error: No deployment found for: DataRegistryProxy的报错可忽略，到官网查询是否部署成功即可。"

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
	    echo "======================= wana 一键部署脚本======================="
		echo "当前版本：$current_version"
		echo "沟通电报群：https://t.me/lumaogogogo"
		echo "推荐配置：1C8G50G"
	    echo "请选择要执行的操作:"
	    echo "1. 部署节点 install_node"
	    echo "2. 部署合约 view_logs"
	    echo "1618. 卸载节点 uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    1) install_node ;;
	    2) contract_creation ;;
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