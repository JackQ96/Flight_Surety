import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let fSApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let fSData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);

const STATUS_CODES = {
    STATUS_CODE_UNKNOWN: 0,
    STATUS_CODE_ON_TIME: 10,
    STATUS_CODE_LATE_AIRLINE: 20,
    STATUS_CODE_LATE_WEATHER: 30,
    STATUS_CODE_LATE_TECHNICAL: 40,
    STATUS_CODE_LATE_OTHER: 50
};
const NUM_ORACLES = 25;
let oracles = {};


fSApp.events.FlightStatusInfo({fromBlock: 0}, (error, event) => {
    if (err) { console.log(error); }
    let res = event.returnValues;
    console.log(`FlightStatusInfo ${res.airline} ${res.flight} ${res.timestamp} ${res.status}`);
});


web3.eth.getAccounts().then((accounts) => {
    fSData.methods.authoriseCaller(config.appAddress)
        .send({ from: accounts[0] });
    fSApp.methods.REGISTRATION_FEE().call().then(fee => {
        for (let i = 1; i < NUM_ORACLES; i++) {
            fSApp.methods.registerOracle()
                .send({ from: accounts[i], value: fee, gas: config.gas })
                .then(result => {
                    fSApp.methods.getMyIndexes().call({ from: accounts[i] })
                        .then(indices => {
                            oracles[accounts[i]] = indices;
                            console.log("Oracle registered");
                        })
                })
                .catch(error => {
                    console.log("Cannot register Oracle");
                });
        }
    })
});

function _randomCode() {
    let statuses = Object.keys(STATUS_CODES);
    let status = statuses[random.int(0, statuses.length-1)];
    return STATUS_CODES[status];
}

fSApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) { console.log(error) }
    let res = event.returnValues;

    const airline = res.airline;
    const flight = res.flight;
    const index = res.index;
    const timestamp = res.timestamp;
    let code = _randomCode();
    
    for ( var key in oracles) {
        var indexes = oracles[key];
        if (indexes.includes(index)) {

            console.log(`${i} OracleRequest: airline ${airline}, flight: ${flight}, time: ${timestamp}, index: ${index}`);
            fSApp.methods.submitOracleResponse(index, airline, flight, timestamp, code)
            .send({from: key, gas: config.gas});
            }
        }});

const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


