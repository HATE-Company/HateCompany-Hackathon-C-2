// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";

// the Dapp contract that will handle the main operations of the dapp like holiding user data and storing of entries
contract blogContract {

    // using the openzeppelin counter contract
    using Counters for Counters.Counter; // OpenZepplin Counter
    Counters.Counter private _ids;
    // Mapping of an address to a user profile
    mapping (address => userProfile) profile;

    // struct for userProfile
    struct userProfile {
        string profileHash; // the user profile will be stored on IPFS and the hash used in the mapping
        uint upVotes; // user total upvotes
    }

    // Mapping to track the entry leaderboard
    mapping (uint => ranking) entryLeaderBoard;

    // Mapping to track the upvotes leaderboard
    mapping (uint => ranking) upvotesLeaderBoard;

    // Mapping to track the headline leaderboard
    mapping (uint => ranking) headlineLeaderBoard;

    // the ranking struct
    struct ramking {
        address user;
        uint score;
    }

    // Mapping of an address to an array posts/entries
    // can be use to retrieve a users posts/entries
    mapping (address => Post[]) userPosts;

    // mapping for blacklist
    mapping (address => bool) blackList;

    // mapping of users to their last post time
    mapping (address => uint) lastPostTime;

    // Mapping of all postcounts/ids to post
    // to store all posts
    mapping (uint => Post) AllPosts;

    // Mapping of an address to the number of entries a user has made
    mapping (address => uint) postsCount;

    // Mapping of users to their stages
    mapping (address => uint) userCategory; // 1 for bronze, 2 for silver, 3 for gold

    // struct of a post/entry
    struct Post {
        address author; // the writter of the post
        string topic; // the topic being written on
        string postHash; // the hash of the object stored on IPFS
        uint upVotes; // the number of upvotes for a post
    }
    
    // struct of a comment on a post
    struct Comment {
        address author; // writter of comment
        string commentHash; // the comment object will be stored on IPFS and the hash stored on chain
        uint upVotes; // the number of upvotes for a post
    }

    // mapping to keep hold of silverwaitList members
    mapping (address => bool) silverWaitList;

    // mapping to keep hold of goldwaitList members
    mapping (address => bool) goldWaitList;

    // Mapping of a post id to comments
    mapping (uint => Comment[]) comments;

    // array of the available topics that can be written about
    // topics can be added by those are gold tier
    string[] topics;

    // Address of the owner of the contract
    // will have some authority/right to perform certain actions
    // like approval for minting NFTs
    address public owner;

    // The thresholds for different levels
    // when reached users can mint different NFTs
    uint public silverLimit; // the number of posts needed to get to silver rank
    uint public goldLimit; // the number of posts needed to get to gold rank

    constructor(uint _silverLimit, uint _goldLimit) {
        owner = msg.sender;
        silverLimit = _silverLimit;
        goldLimit = _goldLimit;

    }

    // function to sign a user up
    function signUp(string memory profileHash) public {
        profile[msg.sender].profileHash = profileHash; // the profile object has to be stored on IPFS already and the hash returned
        userCategory[msg.sender] = 1; // 1 to denote bronze
    }

    // function to make an entry/post
    function postEntry(string memory entryHash, string memory topic) public {
        uint category = userCategory[msg.sender];
        require(category == 3, "You are not a gold member");
        require(blackList[msg.sender] != true, "You have blackListed");
        require(block.timestamp > lastPostTime[msg.sender] + 1 hours);

        _ids.increment();
        Post memory p;
        p.author = msg.sender;
        p.topic = topic; // the topic of the entry
        p.postHash = entryHash; // the entry contents object has to be stored on IPFS already and the hash returned
        p.upVotes = 0;
        uint id = _ids.current();

        userPosts[msg.sender].push(p);
        AllPosts[id] = p;
        postsCount[msg.sender] = postsCount[msg.sender] + 1;

        lastPostTime[msg.sender] = block.timestamp;
    }

    // function to return a user category
    function getCategory(address user) view public returns (string memory category) {
        if (userCategory[user] == 1) {
            category = "bronze";
        } else if(userCategory[user] == 2) {
            category = "silver";
        }
        else {
            category = "gold";
        }
    }

    // function to create new topic, can only be done by a gold user
    function createTopic(string memory topic) public {
        require(userCategory[msg.sender] == 3, "You have to be gold user to user to add topics");
        require(blackList[msg.sender] != true, "You have blackListed");
        topics.push(topic);
    }

    // function to return all topics
    function getTopics() view public returns (string[] memory) {
        return topics;
    }

    // function to make a comment on a post
    function comment(uint id, string memory commentHash) public {
        require(blackList[msg.sender] != true, "You have blackListed");
        require(block.timestamp > lastPostTime[msg.sender] + 1 hours);
        Comment memory c;
        c.author = msg.sender;
        c.commentHash = commentHash;
        c.upVotes = 0;

        comments[id].push(c);
        lastPostTime[msg.sender] = block.timestamp;
    }

    // function to up vote a post
    function upvotePost(uint id) public {
        require(blackList[msg.sender] != true, "You have blackListed");
        AllPosts[id].upVotes = AllPosts[id].upVotes + 1;
        
    }

    // function to up vote a comment
    function upvoteComment(uint id, uint cId) public {
        require(blackList[msg.sender] != true, "You have blackListed");
       Comment[] memory _comments = comments[id];
        Comment memory comment = _comments[cId];
        comment.upVotes = comment.upVotes + 1;
    }

    // function to enter silver waitlist
    function getSilver() public {
        uint cat = userCategory[msg.sender];
        uint votes = profile[msg.sender].upVotes;

        require(cat == 1, "You need to be a bronze holder");
        require(votes >= silverLimit, "You have reached the right threshold for get a silver NFT");
        require(blackList[msg.sender] != true, "You have blackListed");

        silverWaitList[msg.sender] = true;
        userCategory[msg.sender] = cat + 1;
    }

    // function to enter gold waitlist
    function getGold() public {
        uint cat = userCategory[msg.sender];
        uint votes = profile[msg.sender].upVotes;

        require(cat == 2, "You need to be a bronze holder");
        require(votes >= goldLimit, "You have reached the right threshold for get a silver NFT");
        require(blackList[msg.sender] != true, "You have blackListed");

        goldWaitList[msg.sender] = true;
        userCategory[msg.sender] = cat + 1;
    }

    // function to remove a user from a waitlist after the NFT has been minted
    function updateSL() external {
        silverWaitList[msg.sender] = false;
    }
    function updateGL() external {
        goldWaitList[msg.sender] = false;
    }

    // TODO
    // FUNCTION TO ADD A USER TO BLACKLIST
    function addToBlackList(address user) public {
        require(msg.sender == owner, "You are permitted to perform this function");
        blackList[user] = true;
    }
    // FUNCTION TO REMOVE A USER FROM BLACKLIST
        function addToBlackList(address user) public {
        require(msg.sender == owner, "You are permitted to perform this function");
        blackList[user] = false;
    }
    // IMPLEMENTATION OF FEES FOR POSTING

    // IMPLEMENTATION OF LEADERBOARD (WEEKLY AND ALLTIME)

    // IMPLEMENTING REVENUE DISTRIBUTION
}