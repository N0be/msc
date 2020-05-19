pragma solidity ^0.4.19;
pragma experimental ABIEncoderV2;
import "github.com/provable-things/ethereum-api/provableAPI_0.4.25.sol";
import "github.com/Arachnid/solidity-stringutils/strings.sol";

contract Prescriptions is usingProvable {
    using strings for *;
    
    event LogConstructorInitiated(string nextStep);
    event LogPriceUpdated(string price);
    event LogNewProvableQuery(string description);
    event Processed (uint delta);
    
    string public returnValue;
    string public publicCF;
    string public path;
    string public teststring;
    uint public submissionTime;
    event newDrug(string drug);
    string[] public tempdrug;
    
  struct Patient {
    string cf;
    Prescription [] prescrs;
  }
  
  struct Prescription {
    string drug;
    string formula;
    uint dailydose;
    uint category;
    uint incompatibility;
  }
  
  mapping (string => uint) entry;
  Patient [] public patientsList;

  function areTheyEqual(string a, string b) public pure returns(bool) {
        if(bytes(a).length != bytes(b).length) {
          return false;
        } else {
          return keccak256(a) == keccak256(b);
        }
    }
  
  function setValues(string s, uint t){
    publicCF=s;
    submissionTime=t;
  }
    
  function getLength(Prescription[] p) constant public returns(uint l){
    return p.length;
  }
  
  function getPrescriptionDrug(string retrCF, uint8 index) constant public returns(string res){
    return patientsList[entry[retrCF]].prescrs[index].drug;
  }

  function getPrescriptionCategory(string retrCF, uint8 index) constant public returns(uint res){
    return patientsList[entry[retrCF]].prescrs[index].category;
  }
  
  function getEntry(string retrCF) constant public returns(uint res){
    return entry[retrCF];
  }
  
  function getTempCat() view returns (string result) {
        return tempdrug[0];
  }
    
  function getTempIncomp() view returns (string result) {
        return tempdrug[1];
  }
  
  function stringToUint(string s) constant returns (uint result) {
        bytes memory b = bytes(s);
        uint i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint c = uint(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
  }
//This function receives a patient ID as a string and check if it exists in the contract storage
  function ExistsPatient(string lookupCF) public view returns(bool exists) {
    if (patientsList.length == 0) return false;
    return (areTheyEqual(patientsList[entry[lookupCF]].cf,lookupCF));
  }
  
//This function receives a patient ID as a string and a drug name and check if the given drug is already prescribed to the patient in the contract storage
  function ExistsPrescription(string prescriptionCF, string retrDrug) public view returns(bool exists) {
    require(ExistsPatient(prescriptionCF));
    uint l = getLength(patientsList[entry[prescriptionCF]].prescrs);
    for (uint8 i=0; i<l; i++) {
      if (areTheyEqual(patientsList[entry[prescriptionCF]].prescrs[i].drug, retrDrug)) {
        return true;
      }
    }
    return false;
  }
  
//This function receives a patient ID as a string and adds it to the contract storage
  function InsertPatient(string newCF) public returns(bool success) {
    require(!ExistsPatient(newCF));
    Patient storage p1;
    p1.cf = newCF;
    entry[newCF] = patientsList.push(p1) - 1;
    return (areTheyEqual(patientsList[entry[newCF]].cf , newCF));
  }
 
//This function receives a patient ID as a string, a prescriptions and the timestamp of the submission and checks if the given drug is already prescribed to the patient.
//If it is, it invokes the "Update" function, otherwise it invokes the "NewPrescription" one
  function AddPrescription(string prescriptionCF, Prescription newPres, uint subTime) public returns(bool exists) {
    require(ExistsPatient(prescriptionCF));
    if (ExistsPrescription(prescriptionCF, newPres.drug)) {
      return Update(prescriptionCF, newPres);
    }
    NewPrescription(prescriptionCF, newPres, subTime);
    return true;
  }
 
  function updatePrice(string access) payable {
       if (provable_getPrice("URL") > this.balance) {
           LogNewProvableQuery("Provable query was NOT sent, please add some ETH to cover for the query fee");
       } else {
           LogNewProvableQuery("Provable query was sent, standing by for the answer..");
           provable_setCustomGasPrice(4000000000);
           provable_query("URL", strConcat("xml(https://incharge.rocks/drugs).drugs.",access), 400000);
       }
   }
 
//This is the return function after oracle invocation, it received the retrieve string and after parsing it, it invokes the "AcceptPrescription" function.
  function __callback(bytes32 myid, string result) {
       if (msg.sender != provable_cbAddress()) revert();
       returnValue = result;
       LogPriceUpdated(result);
       if (areTheyEqual(result,"")) 
            {
            DeleteElem(publicCF);
            emit Processed(block.timestamp - submissionTime);
            return;}
       tempdrug=eval(returnValue);
       AcceptPrescription(publicCF,stringToUint(tempdrug[1]),stringToUint(tempdrug[0]));
       emit Processed(block.timestamp - submissionTime);
   }
  
//This function receives a patient ID as a string, a prescription and the timestamp of the submission and adds the given prescription in the patient's records inside the contract storage
  function NewPrescription(string prescriptionCF, Prescription newPres, uint timestamp) public {
    patientsList[entry[prescriptionCF]].prescrs.push(newPres);
    setValues(prescriptionCF, timestamp);
    updatePrice(newPres.drug);
  }
  
//This function receives a patient ID as a string and two integers, representing the category the currently considered drug belongs to and the one it is incompatible with and checks if the current prescription is compatible with and decides whether delete or keep the prescription according to the result provided by the "ExistsCategory" function
  function AcceptPrescription(string s, uint a, uint b) public returns (bool accepted) {
      if (ExistsCategory(s,a,b)) {
          DeleteElem(s);
          return false;
      }
      else{
          return UpdateCategory(s,a,b);
      }
  }
  
//This function receives a patient ID as a string and two integers, representing the category the currently considered drug belongs to and the one it is incompatible with and updates the stored record for the prescription considered with the new values
  function UpdateCategory(string CF, uint newInc, uint newCat) public returns(bool success) {
    uint l = getLength(patientsList[entry[CF]].prescrs);
    Prescription p = patientsList[entry[CF]].prescrs[l-1];
    p.category = newCat;
    p.incompatibility = newInc;
    patientsList[entry[CF]].prescrs[l-1]=p;
    return true;
  }
  
//This function receives a patient ID as a string and removes the patient's last prescription from the contract memory
  function DeleteElem(string deleteCF) {
    patientsList[entry[deleteCF]].prescrs.length--;
  }
  
//This function receives a patient ID as a string and a new prescription and update the current prescription for the given drug with the new one
  function Update(string CF, Prescription newPres) public returns(bool success) {
    uint l = getLength(patientsList[entry[CF]].prescrs);
    for (uint8 i=0; i<l; i++) {
      if (areTheyEqual(patientsList[entry[CF]].prescrs[i].drug, newPres.drug)) {
        patientsList[entry[CF]].prescrs[i] = newPres;
        return true;
      }
    }
    return false;
  }
  
//This function receives a patient ID as a string and two integers, representing the category the currently considered drug belongs to and the one it is incompatible with and check if there's any incompatibility with the ongoing prescriptions of the patient stored inside the contract memory
  function ExistsCategory(string prescriptionCF, uint inc, uint cat) public view returns(bool exists) {
    Prescription[] p = patientsList[entry[prescriptionCF]].prescrs;
    uint l = getLength(p);
    for (uint8 i=0; i<l; i++) {
     if (p[i].category == inc) {
        return true;
      }
     else if (p[i].incompatibility == cat)   {
         return true;
     }
    }
    return false;
  }
  
  function eval(string source) pure public returns (string[] result) {
      var s = source.toSlice();
      var delim = ",".toSlice();
      var parts = new string[](s.count(delim) + 1);
      for(uint i = 0; i < parts.length; i++) {
        parts[i] = s.split(delim).toString();
      }
      return parts;
  }
  
  function kill(address to) public {
        selfdestruct(to);
  }
  
  function() public payable {
  }
  
}