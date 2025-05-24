#!/bin/bash

# Создаем структуру папок
mkdir -p ~/holesky/{execution,consensus}/data && cd ~/holesky || exit

# Создаем docker-compose.yml
cat << 'EOF' > docker-compose.yml
services:
  execution:
    image: ethereum/client-go:stable
    container_name: ethereum-execution-holesky
    restart: unless-stopped
    command:
      - "--holesky"
      - "--datadir=/data"
      - "--syncmode=snap"
      - "--txlookuplimit=0"
      - "--cache=1024"
      - "--http"
      - "--http.addr=0.0.0.0"
      - "--http.port=8545"
      - "--http.api=eth,net,web3,engine"
      - "--http.vhosts=*"
      - "--http.corsdomain=*"
      - "--authrpc.addr=0.0.0.0"
      - "--authrpc.port=8551"
      - "--authrpc.vhosts=*"
      - "--authrpc.jwtsecret=/jwtsecret/jwt.hex"
    ports:
      - "8544:8545"
      - "8550:8551"
    volumes:
      - ./execution/data:/data
      - ./execution/jwtsecret:/jwtsecret
    networks:
      - holesky-net

  consensus:
    image: sigp/lighthouse:latest
    container_name: ethereum-consensus-holesky
    restart: unless-stopped
    command:
      - "lighthouse"
      - "beacon_node"
      - "--network=holesky"
      - "--datadir=/data"
      - "--http"
      - "--http-address=0.0.0.0"
      - "--http-port=5052"
      - "--checkpoint-sync-url=https://holesky-checkpoint-sync.stakely.io"
      - "--execution-endpoint=http://execution:8551"
      - "--execution-jwt=/jwtsecret/jwt.hex"
    ports:
      - "9001:9000/tcp"
      - "9001:9000/udp"
      - "5053:5052"
    volumes:
      - ./consensus/data:/data
      - ./execution/jwtsecret:/jwtsecret
    depends_on:
      execution:
        condition: service_started
    networks:
      - holesky-net

networks:
  holesky-net:
    driver: bridge
EOF

# Генерируем JWT-секрет
mkdir -p ./execution/jwtsecret
openssl rand -hex 32 | tr -d '\n' > ./execution/jwtsecret/jwt.hex
chmod 644 ./execution/jwtsecret/jwt.hex

# Открываем порты в firewall (если ufw)
if command -v ufw >/dev/null 2>&1; then
  sudo ufw allow 8544/tcp comment "Holesky JSON-RPC"
  sudo ufw allow 8550/tcp comment "Holesky Auth-RPC"
  sudo ufw allow 9001/tcp comment "Holesky P2P TCP"
  sudo ufw allow 9001/udp comment "Holesky P2P UDP"
  sudo ufw allow 5053/tcp comment "Holesky Beacon API"
  echo "Порты 8544, 8550, 9001 и 5053 открыты в firewall"
fi

# Запускаем ноду
docker compose up -d

# Получаем IP-адрес
IP_ADDR=$(hostname -I | awk '{print $1}')

# Выводим итоговую информацию
cat << EOF


=== УСТАНОВКА ЗАВЕРШЕНА ===

RPC endpoints:
holesky: http://${IP_ADDR}:8544
Beacon: http://${IP_ADDR}:5053

Команды для логов:
docker logs -f ethereum-execution-holesky
docker logs -f ethereum-consensus-holesky
EOF
