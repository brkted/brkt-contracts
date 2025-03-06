# BRKT Move Contracts

The BRKT Move Contracts project is structured to manage various types of competitions using the Move programming language. The project is organized into several modules, each responsible for different aspects of the competition management system. Below is an overview of the logic and structure of the smart contracts in this project:

### 1. Key Modules and Their Responsibilities
- `competition_factory` is responsible for creating and managing different types of competitions.

- `competition_state` manages the state of a competition, including teams, rounds, and match outcomes.

- `predictable_competition_state` extends CompetitionState to include prediction-related data.

- `paid_predictable_competition` manages competitions that require a registration fee and handle rewards.

- `predictable_competition` manages competitions where users can make predictions.


### 2. Compile, Publish and Execute Modules
#### 2.1. Install Aptos (Linux)

1. Ensure you have Python3.6+
2. In the terminal, use one of the following commands:
    ```
    $ curl -fsSL "https://aptos.dev/scripts/install_cli.py" | python3
    ```
    Or use the equivalent `wget` command:
    ```
    $ wget -qO- "https://aptos.dev/scripts/install_cli.py" | python3
    ```
3. Verify the script is installed by opening a new terminal and running `aptos help`

*Check [`aptos.dev`](https://aptos.dev/en/build/cli) for other ways or operating systems.*

#### 2.2. Compile modules
Using the following command to compile modules:
```
$ sudo aptos move compile --package-dir sources
```
For more options, check `sudo aptos move compile --help`

#### 2.3. Publish modules
##### 2.3.1. Account
Ensure that you have a valid account in the `.aptos/config.yaml` file, e.g.
```
---
profiles:
  default:
    private_key: "0x0000000000000000000000000000000000000000000000000000000000000000"
    public_key: "0x0000000000000000000000000000000000000000000000000000000000000000"
    account: 0000000000000000000000000000000000000000000000000000000000000000
    rest_url: "https://fullnode.devnet.aptoslabs.com"
    faucet_url: "https://faucet.devnet.aptoslabs.com"
```

To create an account, check `sudo aptos init --help`

##### 2.3.2. Setup `Move.toml` file
Change the value of `brkt_addr` variable to fit your account, e.g.
```
[package]
name = "brkt"
version = "1.0.0"
authors = []

[addresses]
brkt_addr='0000000000000000000000000000000000000000000000000000000000000000'

[dev-addresses]

[dependencies.AptosFramework]
git = "https://github.com/aptos-labs/aptos-core.git"
rev = "mainnet"
subdir = "aptos-move/framework/aptos-framework"

[dev-dependencies]
```

##### 2.3.3. Publish modules
Using the following command to publish modules:
```
$ sudo aptos move publish --profile <the-account-name-in-the-config.yaml-file>
```

For more options, check `sudo aptos move publish --help`

#### 2.4. Execute modules using Aptos Explorer

1. Access the [`Aptos Explorer`](explorer.aptoslabs.com/)
2. Choose your blockchain network 
3. Search for the published account address in the explorer
4. Access to the `Modules` tab
5. Now, you can check the code in the `Code` tab, execute functions in the `Run` tab, or call view functions in the `View` tab
