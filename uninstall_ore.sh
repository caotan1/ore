#重新加载服务
sudo systemctl daemon-reload
#关闭ore进程
sudo pkill -9 ore-miner
#删除ore服务
sudo rm -r /etc/systemd/system/ore.service
