# iOS Application
 
## Requirements

- XCode version 15.4 or higher.

## How to start

1. Open the source code by running:
```open cardioflow.xcodeproj```
2. Enter your developer team ID.
3. Build and install the application on the device(s).
4. Optional: When replacing the model in the [cardioflow/Ressources](./cardioflow/Ressources/) directory, ensure to select the file for copying to the device in the Build Phases tab. This step is required to ensure the model is available on-device in a non-compiled version, which is required for federated learning routines using the Flower framework.
