pragma solidity ^0.6.1;
pragma experimental ABIEncoderV2;

contract Transport{
    
  constructor() public { owner = msg.sender; }
  address payable owner;
  
  event Processed (uint delta);
    
  struct Measure {
    uint temperature;
    uint time;
  }
  
  struct StoredRecord {
  Measure[] smeasures;
  bool saccuracy;
  bool scompleteness;
  bool sprecision;
  bool stimeliness;
  }
  
  StoredRecord[] public mem;
  uint public count;

//This function measures the average temperature from a batch of measurements, provided as an array of temperature-timestamp pairs  
  function avgTemp(Measure [] memory values) pure public returns (uint m) {
      m = 0;
      for (uint i=0; i<values.length; i++) {
        m = m + values[i].temperature;
      }
      m = m / values.length;
      return m;
  }  
  
  function getAccuracy(uint i) view public returns(bool res){
    return mem[i].saccuracy;
  }
  
    function getCompleteness(uint i) view public returns(bool res){
    return mem[i].scompleteness;
  }
  
    function getPrecision(uint i) view public returns(bool res){
    return mem[i].sprecision;
  }
  
    function getTimeliness(uint i) view public returns(bool res){
    return mem[i].stimeliness;
  }
    function getMeasures(uint i) view public returns(Measure[] memory a){
    return (mem[i].smeasures);
  }
  
//This function receives an array of measures, all the additional parameters needed for DQ assessment and invokes the correspondent functions to assess the single metrics storing the results in memory.
//Before returning it stores the measures in the contract memory
  function evaluateStream(Measure [] memory values, uint accuracyTemperature, uint accuracyTolerance, uint accuracyTrigger, uint completenessLenght, uint precisionTolerance, uint timelinessDelta, uint timelinessTrigger, uint submissionTime) payable public returns (bool ok) {
      mem.push();
      uint t=values.length;
      mem[count].saccuracy = Accuracy(values, accuracyTemperature, accuracyTolerance, accuracyTrigger);
      mem[count].scompleteness = Completeness(values, completenessLenght);
      mem[count].sprecision = Precision(values, precisionTolerance);
      mem[count].stimeliness = Timeliness(values, timelinessDelta, timelinessTrigger);
      for (uint8 i=0; i<t;i++)    {
          mem[count].smeasures.push(values[i]);
      }
      count++;
      emit Processed(block.timestamp - submissionTime);
      return true;
  }
  
//This function receives a batch of measures, the reference value, the accepted tolerance and the number of consecutive out of range values needed to mark the batch as non qualitative and then it assesses accuracy of the given batch (true/false)
  function Accuracy(Measure [] memory values, uint mtemperature, uint tolerance, uint trigger) public pure returns (bool check) {
      uint8 conta = 0;
      for (uint8 i=0; i<values.length; i++) {
            if (values[i].temperature>(mtemperature+tolerance) || values[i].temperature<(mtemperature-tolerance)) {
              conta++;
              if (conta == trigger) {
                  return false;
              }
            }
            else conta = 0;
      }
      return true;
  }

//This function receives a batch of measures and the expected batch lenght and, by comparing the two values, it returns completeness (true/false)
  function Completeness(Measure [] memory values, uint len) pure public returns (bool complete) {
      if (values.length == len)
        return true;
      return false;
  }  
  
//This function receives a batch of measures and the maximum standard deviation accepted and, after measuring the standard deviation of the received batch it assesses precision by comparing it with the threshold (true/false)
  function Precision(Measure [] memory values, uint threshold) pure public returns (bool ok) {
      uint m = avgTemp(values);
      uint sqm;
      for (uint8 i=0; i<values.length; i++) {
        if (values[i].temperature >= m)
          sqm = sqm + ((values[i].temperature-m)*(values[i].temperature-m));
        else
          sqm = sqm + ((m-values[i].temperature)*(m-values[i].temperature));
      }
      sqm = sqm / values.length;
      if (sqm > (threshold*threshold)) {
          return false;
      }
      return true;
  }  
  
//This function receives a batch of measures, the maximum delay accepted and the number of consecutive out of range values needed to mark the batch as non qualitative and then it assesses timeliness of the given batch (true/false) 
  function Timeliness(Measure [] memory times, uint delta, uint trigger) view public returns (bool ok) {
      uint conta = 0;
      uint cur = now;
      uint normalized = 0;
      for (uint8 i=0; i<times.length; i++) {
            normalized = (cur-(60*(times.length-i)));
            if ((normalized > times[i].time) && ((normalized-times[i].time)>delta)) {
              conta++;
              if (conta==trigger)    {
                  return false;
              }
            }
            else conta = 0;
      }
      return true;
  }   

//This function is needed in order to cancel the contract from the blockchain whenever it is no longer needed. Only the contract creator address can invoke it.
  function destroy() public {
        if (msg.sender == owner) selfdestruct(owner);
  }
  
//The fallback function is needed for the contract to receive Ether
  fallback() external payable {
  }
}