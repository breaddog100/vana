#!/bin/bash

# 设置版本号
current_version=20240927002

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

# 部署环境
function install_env() {

    sudo apt update
    sudo apt install -y make build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python3-openssl git python3-poetry

    # 安装Python
    curl https://pyenv.run | bash
    echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> .bashrc
    echo 'eval "$(pyenv init --path)"' >> .bashrc
    echo 'eval "$(pyenv init -)"' >> .bashrc
    echo 'eval "$(pyenv virtualenv-init -)"' >> .bashrc
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> .bashrc
    source .bashrc
    pyenv install 3.11.10
    pyenv local 3.11.10
    python --version
    pip install --upgrade pip
    pip install vana
    pip install --upgrade aiohttp ansible ansible-vault colorama eth-abi fastapi munch netaddr password-strength pydantic pynacl python-dotenv python-statemachine requests retry rich shtab uvicorn web3
    pip install ansible==9.9.0 fastapi==0.111.0 uvicorn==0.29.0 web3==6.20.3

    # 安装yarn
    sudo apt remove cmdtest
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt update && sudo apt install yarn -y
    yarn --version

    # 安装node
    curl -O https://deb.nodesource.com/setup_18.x
    sudo -E bash setup_18.x -y
    sudo apt install -y nodejs
    # 如果报错
    sudo dpkg -i --force-overwrite /var/cache/apt/archives/nodejs_18.20.4-1nodesource1_amd64.deb
    sudo apt --fix-broken install
    sudo apt autoremove
    sudo apt update
    sudo apt remove libnode72
    sudo apt install -y nodejs
    node -v

    # clone GPT 代码
    git clone https://github.com/vana-com/vana-dlp-chatgpt.git
    cd $HOME/vana-dlp-chatgpt/

    # 配置环境
    cp .env.example .env
    sed -i 's/\[tool.poetry.group.dev.dependencies\]/[tool.poetry.dev-dependencies]/' pyproject.toml
    poetry env use 3.11.10
    poetry install
    poetry env use $(pyenv which python)

    # clone 合约代码
    cd $HOME
    git clone https://github.com/vana-com/vana-dlp-smart-contracts.git 
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
    WALLET_NAME=default
    echo "钱包名称为default，密码要用字母和数字，请保存coldkey和hotkey的所有信息："
    ./vanacli wallet create --wallet.name $WALLET_NAME --wallet.hotkey $WALLET_NAME
    echo "下面是钱包对应私钥，导入钱包后使用地址领水："
    # 导出cold key私钥
    ./vanacli wallet export_private_key
    # 导出hot key私钥
    ./vanacli wallet export_private_key --wallet.hotkey $WALLET_NAME
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
    ./keygen.sh

    cd $HOME/vana-dlp-smart-contracts/
    sed -i "s/^DEPLOYER_PRIVATE_KEY=.*$/DEPLOYER_PRIVATE_KEY=$DEPLOYER_PRIVATE_KEY/" .env
    sed -i "s/^OWNER_ADDRESS=.*$/OWNER_ADDRESS=$OWNER_ADDRESS/" .env
    sed -i "s/^DLP_NAME=.*$/DLP_NAME=$DLP_NAME/" .env
    sed -i "s/^DLP_TOKEN_NAME=.*$/DLP_TOKEN_NAME=$DLP_TOKEN_NAME/" .env
    sed -i "s/^DLP_TOKEN_SYMBOL=.*$/DLP_TOKEN_SYMBOL=$DLP_TOKEN_SYMBOL/" .env

    # 需要有水
    npx hardhat deploy --network satori --tags DLPDeploy --gasprice 1200000000
    echo "如果出现类似Error: No deployment found for: DataRegistryProxy的报错可忽略，到官网查询是否部署成功即可。"

}

# 创建验证者
function create_validator(){
    echo "coming sooooooooooon"
    # 修改.env文件
    #DLP_CONTRACT_ADDRESS=0x725B6aaf3fF5516B5B2148F4C83D0D7316c2dd38
    #DLP_SATORI_CONTRACT=0x725B6aaf3fF5516B5B2148F4C83D0D7316c2dd38
    #DLP_TOKEN_SATORI_CONTRACT=0x877c885B8a4309FC2E8C2AB396d472541B408Dc8
    #PRIVATE_FILE_ENCRYPTION_PUBLIC_KEY_BASE64=LS0tLS1CRUdJTiBQR1AgUFVCTElDIEtFWSBCTE9DSy0tLS0tCgptUUdOQkdicnN0Y0JEQUNhWkJtTmJtdTdYYXE0SkxlRjM3MmJTc1RCYWxxbitzZTJiMEtNcUhSdkNjaGhENXJnCk9yM3RkRVJURTVaRlBTQjVSY0xFWVZWbVNwSnp3aU51T09KNE9mQkxPUjNMeTZBNUVhOHB1OGs4a2szUXVNd3YKeEljUHlMejc1cXhLenNTTXVoWTdJdHYzbWJrYi9VbXRyc3BvWTk3VlRvbWhvcGlVTEw1SXZPMnN1T3R2ZXBCYgpCYUVhY1RWMzdSNXJzZ2JqOFJEOEUrc3RhZFdmUmtQdzZLT2Q3YlluWUVWOExRQmY2dDhpSStwOG9aL1FJSjlSCmpmZ29MQnl1UkZDSlE1UitrZE9uQVkwOEN2RkM5RC9mb1lIckRoV1ZVZzJTekJ2NHN5VXdzcUpySnBLam0yUjAKUmhSL0x3d005WVp2R1ROd3ZEZ2EybERsZGJLSVpoeFJSUEM3QzNWR256SXp6alBTcUQrYTRzemlCbzhoQTNUagpiWEZ0N3o1UHNoYW1hN0NRK2xhSW5TRndvcCt1YWdLVDkxZ1pza0dLYVNXRURQV05tWHdzMjlXb0c5TjZKdXA0CmxzazJrU1E0dmU4RVB4c1BOcWMwK0tZclY2WlpJT3lTQVNsYXcxU3RBTFFxZ2FrdjRkQ21LaDV6WThGMmNoNGUKZTFra2ExdEg5Y0xRcGpVQUVRRUFBYlFmYlc5dVkybGphU0E4Ylc5dVkybGphVEl4TVRsQVoyMWhhV3d1WTI5dApQb2tCemdRVEFRb0FPQlloQlA2TWJJdEc5czd2NGZ3NDFqSFRxVjFtZ2p1L0JRSm02N0xYQWhzdkJRc0pDQWNDCkJoVUtDUWdMQWdRV0FnTUJBaDRCQWhlQUFBb0pFREhUcVYxbWdqdS80YmdMLzJtd0wrM2lmZFROSHd1amgyQ0EKUnJuOStkaTVmeHBlSTg3VHd1NmV1U1UrVkw5VXhJNWZieHpKckZaenBIV3U2SjJOMk5uYWNOdGVQcHkydFJDNwp6TURRQ2Q2YmNqdG9XZWE1ZjFMOWxwTWZtc3lqRHJGNENhSlljVlJVanIxd0dBdER6ajRuRWNSbXYrbHg5QmU5ClpLNngzNzBUZVhOOWE2Y3dPUnZJSUNGc1c4bzA3dXZydCszRlloOENaRXRER0FkeXJuOU56QmJTd29FVkRoWm8KcFYxMnRTcGQzUm0wK0JPamhIUER6K2NydDAvMXk4R1RoS29ocWh4QkY3MkZSOUxic0NTbDgzVit3V01nbWFZawpuem1MMkJ2eW9IS3NiU1hDNnVLb05vcnNTVjRDT2RaWFV6NzhsTjl0K2MvZ0lRUGRVVWlqMGdtNE1YTUovMjJYCmxNRXl2dkVVOXBWUldORmdnak5URm0xaW52UzZTM3ZoRDBQYWlrS1VLWXhXWkVxRDg1c1hpR292akVRTGlMamoKY1h2bFhBeFJ1cXVuckJjSktISkMxS1dFdldIYzZPM0lWSkxaZmRvemxmb0xBQStsalJpbHdRTVdrTVdLV3RNWQpwWFRMT2w4RmR4VldtdXZEdUZUMUxmcEtzRmh2Q2dWeG9GMEYxNmREVzVLSGM3a0JqUVJtNjdMWEFRd0E4V0Q4CkppUGRoMWJuTzRhOE1teW5BeUp1WlB3TXhNU0V5ZXdzbVljZzN6YWR3Y3BLcFNORU5SdDM3ODBPVExXdElSb3oKcjRmdlZVb1d2amNBU0JiNkROcmdNZjBraTRXNC9rVXVqTytWNGppK3B3V1pjUTlpZDA4b3FaQTJnTktIOHFERwpnSVNmd252d2JHR0V6YVlaYUpKVUI0UGFpQk9sMVlYa2pUdUcxOXVjT1d3eHhaVElQbHZGVXlLUEdSY0EwQ2JqCitiK0pvZ1JabWxiclFRNXhlWlhVR3A3WEI5U0RDSzE4VmtoN1ErdTdPREk5eVZpTDVCSlZZaEZUUGlPRVlUem0KNnNwWEMveFpRYU1VWlYxQ09Wd1JCaFJ1ZjRqWGlHbVhycjViM1NFbEJCTFUxdE1KWUtpZkw5S2swTTg1YkRNRgpyNDg2a3JzUE5JQXowVEpLZ2Z2WXpPc2wyTHcwaktrN25OOFNZdkdua0dlREpBajVKTVNSWDlPOFlkOVY4Yk1xCm9kcDFoaTJNTklNOXJyZU1xM3NLNTV3T2lIOFp6bzl3N0I5Wjd1cGxtNnk2Smg0a2U4cnQ4VnEyQW9DcnhoaDAKQ0xSbUNDeUdBanAwVEJybUtqLzAyMHI3aVZZT2E0UnVtYW84NENvWTBGRldNN2J6NzZ2eUVwUHEraVhIQUJFQgpBQUdKQTJ3RUdBRUtBQ0FXSVFUK2pHeUxSdmJPNytIOE9OWXgwNmxkWm9JN3Z3VUNadXV5MXdJYkxnSEFDUkF4CjA2bGRab0k3djhEMElBUVpBUW9BSFJZaEJKb3BDREduVFEwUUVCdFNQYUpJVUpsMmZUVzlCUUptNjdMWEFBb0oKRUtKSVVKbDJmVFc5V0RzTC9qVmdZUFZjT2ozZ2VBdzhZRHZodm9zTGlKMGFSRHhoa3FFVEJXam85ZFdjQjJXUwpPTjdxcEFwV3g0UVR5V0VCakVVcFlvVkhIVTBucmNSVGdNVW1lZFRJcE9vekQ1Uy80QlVvYzJqSXNOZ05OYXpyCjFJckdhdlk4OS9qMVM4R0kzVTNmSXBhMWxOTzhDamdpcTBrWk5XQ3Rwa21PZ2dTaFR3MXRrVnkxWFJwZWhCeWsKSjZrd2ZralpOeG9WVEtEWGhod2xuZk1LZ2ZFUHMrbm5FYU1TcUFaTHhKeHUxUG9HTmV3dmVSeHI5TWNEYzB1eQpLNzAwYVFwSG9FM3RFWCt5a0ErOFpzaVIrZSttekF4QTV2L2ZLMmRSR2RXaTNCRGRLWW9JQXhMZGhDK1pLeHkyCkQwS2lQRmRLMk1RRWRNY3lPSmJ6NTBzWEFHSHNneEdzTEFIQTdTdUVXbHNNUVZzTFQ1WjVwcEQrMzNjTTdLaHYKMXVnNElGSmFjOHVJM0NmRnk0Q0IrcjhzQW1XbEtzZGxuMWFPT0dLbWw4VFR3WDRWMkdnN1ZIRXc1UC9HbUUvQgpOOGt5dU1IbVI4cVJtT081L003cDJ6NGswbHNHTk5iS2YzdTU2RFF0VmpjdzcwUGNvQVhKOGhSRGdadEl3Y0g5CklPbWZCWUl3Wm9YUXovUmR4cURCQy80cC9rcGJFOFhQcG1zZDlmblVmaEx6NEk4NFpCTnBTVFE0ejRaUTc4ZnQKY0NWS2U0WnpGN2JpSXloSFVpdDNiRmFPaVdBTjVwbzBnTSt2RGl3ZGVuNjhjNGg5NkUrL1dMVDNwY2ZQZmNLYwp4c3FYV2tFR0tSeFNVeS9oSlQzdW9kZEhxWTN0cGhLSlRMUklDRzdGSURSWWkzcmJYOURzS2l0UkJhc2ZxaGhNCldBVlZjcmwzdkpnRDJtZ2ZpRUFTeFRiZG1RYnJYMGxERFp2ODJwVWlVTzNJMkdnL3NlRkY0dVQvYkRydkIvUUQKNTUxZFg3RnlLV3Jvak9aWU42ZHhZbkJ6Vm81TU9ybUJuMTJUdXRZVk1lNVpSUFdKZmFVd2dHRWx2cjZpcXdDUApPdmJpdDV0bjB1bWpWalBSUy8yUUNBV3doTHhJRGkzeERUYzF4bEVZbk4yQmljSnZvQmxKaHdublg5cnpDZ2NqCiszWmlYZ0ZMWFhLbzFwc3Z1NmFDUFZoN0lIMFNJVDJPOTFUM2JlaWxDVHp0ak1ZaEhvZUs4ZGhIWVc0enNwTFIKZk9Fb3BtS2g3SkpNajFpSGppOXRFUWVJTjdBZHVFYnpYRnAyQjM0RENCU0hwdFRROWNDcnBHWGtDMDdGWlcxdgpMUXgrYXVDWHExM2Q4aDlURUJ4R2JEcz0KPUpiTDkKLS0tLS1FTkQgUEdQIFBVQkxJQyBLRVkgQkxPQ0stLS0tLQo=

    # 质押代币
    #./vanacli dlp register_validator --stake_amount 10

    # 运行验证者
    #poetry run python -m chatgpt.nodes.validator
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
		echo "推荐配置：1C8G50G"
	    echo "请选择要执行的操作:"
	    echo "1. 部署环境 install_env"
	    echo "2. 创建钱包 create_wallet"
        echo "3. 部署合约 contract_creation"
        echo "4. 创建验证者 create_validator"
	    echo "1618. 卸载节点 uninstall_node"
	    echo "0. 退出脚本 exit"
	    read -p "请输入选项: " OPTION
	
	    case $OPTION in
	    1) install_env ;;
	    2) create_wallet ;;
        3) contract_creation ;;
        4) create_validator ;;
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