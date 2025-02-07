from flask import Flask, request, jsonify
from web3 import Web3
import json

app = Flask(__name__)

# Connect to Camino Network
web3 = Web3(Web3.HTTPProvider('https://camino-network-node'))

# Smart contract ABI and address
contract_abi = [...]  # Add your contract's ABI here
contract_address = "0xYourContractAddress"

# Load the smart contract
contract = web3.eth.contract(address=contract_address, abi=contract_abi)

# Private key for signing transactions
private_key = "0xYourPrivateKey"

@app.route('/webhook', methods=['POST'])
def flight_event_webhook():
    data = request.json
    flight_id = data['flight_id']
    event = data['event']
    timestamp = int(data['timestamp'])

    # Build transaction
    tx = contract.functions.updateFlightEvent(flight_id, event, timestamp).buildTransaction({
        'gas': 200000,
        'nonce': web3.eth.getTransactionCount(web3.eth.defaultAccount),
    })

    # Sign and send transaction
    signed_tx = web3.eth.account.signTransaction(tx, private_key=private_key)
    tx_hash = web3.eth.sendRawTransaction(signed_tx.rawTransaction)
    
    return jsonify({"status": "success", "tx_hash": tx_hash.hex()}), 200

if __name__ == '__main__':
    app.run(port=5000)
