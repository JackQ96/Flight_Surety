import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.config = config;
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    async fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        await self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    async registerAirline(airline, newairline, callback) {
        let self = this;
        await self.flightSuretyApp.methods
            .registerAirline(newairline)
            .send({from: airline, gas: 1000000}, (error, result) => {
                callback(error, result);
            });
    }

    async buy(flight, price, callback) {
        let self = this;
        let payload = {
            flight: flight,
            price: this.web3.utils.toWei(price, "ether"),
            passenger: this.passenger
        }

        await self.FlightSuretyData.methods
            .buy(airline, flight, timestamp, passenger, amount)
            .send({
                from: payload.passenger,
                value: payload.price,
                gas: this.config.gas
            }, (error, result) => {
                callback(error, payload);
            })
    }
}