docker build . -t robo_advisor_yield
docker-compose up -d chain

# give it time to spin up (this can be done in the dependent
# container with netcat checking port 8545
sleep 10

docker-compose up test
