# Federated Learning Server
 
## Requirements

- install the requirements
### shfmt
    pip install -r requirements.txt

## Run

Open the terminal and run:
### shfmt
    python server.py -c 20 -r 50

You can specify the number of minimum required clients and optimization rounds by the flags. The results, i.e., the weights after each round, are saved into the ```./weights``` folder. Make sure it exists when starting the optimization routine.
