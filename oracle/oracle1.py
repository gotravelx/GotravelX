# 4000 flight events per day - 4000 united flights take off every day/
# Sailesh will call web hook for each flight every day ... 4000 calls to web hook
# GOTravelX/FlightLanded?flightid=UA100&Type=landed&time=202502070000000GMT
#--------------------------------
#call the oracle below

#STEP2 ----------- monetization of free flifo data
#1 paying customers need to subscribe to GoTravelX - ABC cleaning , is interetes in UA100 , event "flight landed"
#2 ??? if all true and we execute the SC and write to the chain , that information is public ? is somehow readable by subscribed customers
#3 ??? this is not real time ? customers will not be notified in real time, they will have to go to chain to see new flight evetns ?!?!?!
#4 how do we make a cutomer paying customer ?!!? 
    # go create a walled, or go use your credit card and we will buy coins for you , put them in your waller or in our custodial wallet ?

#5 chain link ?








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

@app.route('/GoTravelX/FlightLanded', methods=['POST']) # this is postman ... we b2.0
def flight_event_webhook():
    data = request.json
    flight_id = data['flight_id']
    event = data['event']
    timestamp = int(data['timestamp'])


    # call the smart contract
    # Build transaction
    tx = contract.functions.updateFlightEvent(flight_id, event, timestamp).buildTransaction({
        'gas': 200000,
        'nonce': web3.eth.getTransactionCount(web3.eth.defaultAccount),
    })

    # Sign and send transaction execute the contract
    signed_tx = web3.eth.account.signTransaction(tx, private_key=private_key)
    tx_hash = web3.eth.sendRawTransaction(signed_tx.rawTransaction)
    
    return jsonify({"status": "success", "tx_hash": tx_hash.hex()}), 200

if __name__ == '__main__':
    app.run(port=5000)
