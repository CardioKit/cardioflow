import flwr
import argparse
import numpy as np

class SaveModelStrategy(flwr.server.strategy.FedAvg):
    def aggregate_fit(
        self,
        rnd: int,
        results,
        failures,
    ):
        weights = super().aggregate_fit(rnd, results, failures)
        if weights is not None:
            # Save weights
            print(f"Saving round {rnd} weights...")
            np.savez(f"./weights/round-{rnd}-weights.npz", *weights)
        return weights

def main(num_clients = 1, num_rounds = 1, weights = "./weights/") -> None:
    
    strategy = SaveModelStrategy(
        min_fit_clients=num_clients,
        min_evaluate_clients=num_clients,
        min_available_clients=num_clients,
    )
    
    hist = flwr.server.start_server(
        server_address="[::]:8080", 
        config=flwr.server.ServerConfig(num_rounds=num_rounds),
        strategy=strategy,
    )
    return hist
    
if __name__ == "__main__":
    argParser = argparse.ArgumentParser()
    argParser.add_argument("-c", "--clients", type=int, help="minimum number of clients", default=1)
    argParser.add_argument("-r", "--rounds", type=int, help="number of rounds", default=1)
    args = argParser.parse_args()
    hist = main(args.clients, args.rounds)
