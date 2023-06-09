// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.17;    

import "./Miracle-Escrow-R2.sol";
import "@thirdweb-dev/contracts/extension/PermissionsEnumerable.sol";
import "@thirdweb-dev/contracts/extension/Multicall.sol";
import "@thirdweb-dev/contracts/extension/ContractMetadata.sol";

//    _______ _______ ___ ___ _______ ______  ___     ___ ______  _______     ___     _______ _______  _______ 
//   |   _   |   _   |   Y   |   _   |   _  \|   |   |   |   _  \|   _   |   |   |   |   _   |   _   \|   _   |
//   |   1___|.  1___|.  |   |.  1___|.  |   |.  |   |.  |.  |   |.  1___|   |.  |   |.  1   |.  1   /|   1___|
//   |____   |.  __)_|.  |   |.  __)_|.  |   |.  |___|.  |.  |   |.  __)_    |.  |___|.  _   |.  _   \|____   |
//   |:  1   |:  1   |:  1   |:  1   |:  |   |:  1   |:  |:  |   |:  1   |   |:  1   |:  |   |:  1    |:  1   |
//   |::.. . |::.. . |\:.. ./|::.. . |::.|   |::.. . |::.|::.|   |::.. . |   |::.. . |::.|:. |::.. .  |::.. . |
//   `-------`-------' `---' `-------`--- ---`-------`---`--- ---`-------'   `-------`--- ---`-------'`-------'
//   Tournament V0.2.0

contract MiracleTournament is PermissionsEnumerable, Multicall, ContractMetadata {
    address public deployer;
    address payable public EscrowAddr;
    uint[] private OnGoingTournaments;
    uint[] private EndedTournaments;

    struct Tournament {
        bool created;
        //The tType defines the tournament type.
        // 1 - Total Score Tournament
        // 2 - Top Score Tournament
        uint8 tournamentType;
        address [] players;
        address [] ranker;
        address organizer;
        uint registerStartTime;
        uint registerEndTime;
        uint prizeCount;
        bool tournamentEnded;
        string scoreURI;
    }

    address admin;
    mapping(uint => Tournament) public tournamentMapping;

    event CreateTournament(uint tournamentId);
    event Registered(uint tournamentId, address account);
    event NewPersonalRecord(uint tournamentId, address account, uint score);
    event ScoreUpdated(uint tournamentId, string uri);
    event TournamentEnded(uint tournamentId); 
    event TournamentCanceled(uint tournamentId);

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant ESCROW_ROLE = keccak256("ESCROW_ROLE");

    constructor(address adminAddr) {
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddr);
        _setupRole(FACTORY_ROLE, adminAddr);
        deployer = adminAddr;
        _setupContractURI("ipfs://QmdFLCkqSK8ZANLP9NnAmVpbHFD5YuiaSvEZwGdYZ4yfZc/BubbleShooterTournamentR2.json");
    }

    function _canSetContractURI() internal view virtual override returns (bool){
        return msg.sender == deployer;
    }

    modifier registrationOpen(uint tournamentId) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp >= tournament.registerStartTime, "Registration has not started yet");
        require(block.timestamp <= tournament.registerEndTime, "Registration deadline passed");
        _;
    }

    function connectEscrow(address payable _escrowAddr) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setupRole(ESCROW_ROLE, _escrowAddr);
        EscrowAddr = _escrowAddr;
    }

    function createTournament(uint _tournamentId, uint8 _tournamentType, address _organizer, uint _registerStartTime, uint _registerEndTime, uint _prizeCount) public onlyRole(ESCROW_ROLE) {
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.created = true;
        newTournament.tournamentType = _tournamentType;
        newTournament.organizer = _organizer;
        newTournament.registerStartTime = _registerStartTime;
        newTournament.registerEndTime = _registerEndTime;
        newTournament.prizeCount = _prizeCount;
        newTournament.tournamentEnded = false;
        
        addOnGoingTournament(_tournamentId);

        emit CreateTournament(_tournamentId);
    }

    function ADMINcreateTournament(uint _tournamentId, uint8 _tournamentType, address _organizer, uint _registerStartTime, uint _registerEndTime, uint _prizeCount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Tournament storage newTournament = tournamentMapping[_tournamentId];
        newTournament.created = true;
        newTournament.tournamentType = _tournamentType;
        newTournament.organizer = _organizer;
        newTournament.registerStartTime = _registerStartTime;
        newTournament.registerEndTime = _registerEndTime;
        newTournament.prizeCount = _prizeCount;
        newTournament.tournamentEnded = false;
        
        addOnGoingTournament(_tournamentId);

        emit CreateTournament(_tournamentId);
    }

    function register(uint tournamentId, address _player) public payable registrationOpen(tournamentId) onlyRole(ESCROW_ROLE){
        Tournament storage tournament = tournamentMapping[tournamentId];
        require(block.timestamp > tournament.registerStartTime, "Registration has not started yet");
        require(block.timestamp < tournament.registerEndTime, "Registration deadline passed");

        tournament.players.push(_player);
        emit Registered(tournamentId, _player);
    }

    function ADMINRegister(uint tournamentId, address _player) public payable onlyRole(DEFAULT_ADMIN_ROLE){
        Tournament storage tournament = tournamentMapping[tournamentId];

        tournament.players.push(_player);
        emit Registered(tournamentId, _player);
    }

    function updateScore(uint tournamentId, string calldata _uri) external onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournamentMapping[tournamentId];
        tournament.scoreURI = _uri;
    }

    function playersShuffle(uint tournamentId) public onlyRole(DEFAULT_ADMIN_ROLE) onlyRole(FACTORY_ROLE){
        Tournament storage tournament = tournamentMapping[tournamentId];
        address[] memory shuffledArray = tournament.players;
        uint n = shuffledArray.length;

        for (uint i = 0; i < n; i++) {
            uint j = i + uint(keccak256(abi.encodePacked(block.timestamp))) % (n - i);
            (shuffledArray[i], shuffledArray[j]) = (shuffledArray[j], shuffledArray[i]);
        }
        tournament.players = shuffledArray;
    }

    function endTournament(uint _tournamentId, address[] calldata _rankers) public onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournamentMapping[_tournamentId];
        uint _prizeCount = tournament.prizeCount;
        address[] memory prizeAddr = new address[](_prizeCount);
        for(uint i = 0; i < _prizeCount; i++){
            prizeAddr[i] = _rankers[i];
        }
        // Unlock Escrow Prize Token / Fee Token to Escrow contract
        MiracleTournamentEscrow(EscrowAddr).unlockPrize(_tournamentId, prizeAddr);
        MiracleTournamentEscrow(EscrowAddr).unlockRegFee(_tournamentId);
        tournament.tournamentEnded = true;

        removeOnGoingTournament(_tournamentId);
        addEndedTournament(_tournamentId);

        emit TournamentEnded(_tournamentId);
    }

    function cancelTournament(uint _tournamentId) public onlyRole(FACTORY_ROLE) {
        Tournament storage tournament = tournamentMapping[_tournamentId];
        
        // Get the list of player addresses
        address [] memory players = tournament.players;
        // Unlock Escrow Prize Token / Fee Token to Escrow contract
        MiracleTournamentEscrow(EscrowAddr).canceledTournament(_tournamentId, players);

        removeOnGoingTournament(_tournamentId);
        addEndedTournament(_tournamentId);

        emit TournamentCanceled(_tournamentId);
    }

    function addOnGoingTournament(uint _tournamentId) internal {
        OnGoingTournaments.push(_tournamentId);
    }

    function addEndedTournament(uint _tournamentId) internal {
        EndedTournaments.push(_tournamentId);
    }

    function removeOnGoingTournament(uint _tournamentId) internal {
        for (uint256 i = 0; i < OnGoingTournaments.length; i++) {
            if (OnGoingTournaments[i] == _tournamentId) {
                if (i != OnGoingTournaments.length - 1) {
                    OnGoingTournaments[i] = OnGoingTournaments[OnGoingTournaments.length - 1];
                }
                OnGoingTournaments.pop();
                break;
            }
        }
    }
    
    function getAllTournamentCount() public view returns (uint) {
        uint count = OnGoingTournaments.length + EndedTournaments.length;
        return count;
    }

    function getOnGoingTournamentsCount() public view returns (uint) {
        return OnGoingTournaments.length;
    }

    function getEndedTournamentsCount() public view returns (uint) {
        return EndedTournaments.length;
    }

    function getOnGoingTournaments() public view returns (uint[] memory) {
        return OnGoingTournaments;
    }

    function getEndedTournaments() public view returns (uint[] memory) {
        return EndedTournaments;
    }

    function getPlayerCount(uint _tournamentId) external view returns(uint _playerCnt){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.players.length;
    }

    function getPlayers(uint _tournamentId) external view returns(address[] memory){
        Tournament storage _tournament = tournamentMapping[_tournamentId];
        return _tournament.players;
    }
}