import torch

class AE(torch.nn.Module):
	def __init__(self):
		super().__init__()
		
		self.encoder = torch.nn.Sequential(
			torch.nn.Linear(500, 100),
			torch.nn.ReLU(),
			torch.nn.Linear(100, 12),
		)
		
		self.decoder = torch.nn.Sequential(
			torch.nn.Linear(12, 100),
			torch.nn.ReLU(),
			torch.nn.Linear(100, 500),
			torch.nn.Sigmoid(),
		)

	def forward(self, x):
		encoded = self.encoder(x)
		decoded = self.decoder(encoded)
		return encoded, decoded
