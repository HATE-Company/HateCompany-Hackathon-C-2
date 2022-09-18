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

    // Mapping of a user to the amount of karma that can be claimed
    mapping (address => uint) claimableKarma;

    // the number of users
    uint usersLength = 0;

    // the ranking struct
    struct ranking {
        address user;
        uint score;
    }

    // preferably using a chainlink price feed to get the price of 0.666 usdc as matic
    // fee for making a comment
    uint commentFee;
    // fee for making a headline
    uint headlineFee;

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

    constructor(uint _silverLimit, uint _goldLimit, uint _commentFee, uint _headlineFee) {
        owner = msg.sender;
        silverLimit = _silverLimit;
        goldLimit = _goldLimit;
        commentFee = _commentFee;
        headlineFee = _headlineFee;

    }

    // function to sign a user up
    function signUp(string memory profileHash) public {
        profile[msg.sender].profileHash = profileHash; // the profile object has to be stored on IPFS already and the hash returned
        userCategory[msg.sender] = 1; // 1 to denote bronze
        usersLength = usersLength + 1; // updating the numbers of users
        entryLeaderBoard[usersLength].user = msg.sender;
        entryLeaderBoard[usersLength].score = 0;

        upvotesLeaderBoard[usersLength].user = msg.sender;
        upvotesLeaderBoard[usersLength].score = 0;

        headlineLeaderBoard[usersLength].user = msg.sender;
        headlineLeaderBoard[usersLength].score = 0;
        claimableKarma[msg.sender] = 0;
    }

    // function to make an entry/post
    function postHeadline(string memory entryHash, string memory topic) public {
        uint category = userCategory[msg.sender];
        require(msg.value == headlineFee);
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

    for (uint i=0; i<usersLength; i++) {
      // get the score of the user, update the score of the user
      if (headlineLeaderBoard[i].user == msg.sender) {
        uint score = headlineLeaderBoard[i].score + 1;
        // find where to insert the new score
        if (headlineLeaderBoard[i].score < score) {

        // shift leaderboard
        ranking memory currentUser = headlineLeaderBoard[i];
        for (uint j=i+1; j<usersLength+1; j++) {
          ranking memory nextUser = headlineLeaderBoard[j];
          headlineLeaderBoard[j] = currentUser;
          currentUser = nextUser;
        }

        // insert
        headlineLeaderBoard[i] = ranking({
          user: msg.sender,
          score: score
        });

      }
      }

    }
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
    function postEntry(uint id, string memory commentHash) public {
        require(msg.value == commentFee);
        require(blackList[msg.sender] != true, "You have blackListed");
        require(block.timestamp > lastPostTime[msg.sender] + 1 hours);
        Comment memory c;
        c.author = msg.sender;
        c.commentHash = commentHash;
        c.upVotes = 0;

        comments[id].push(c);
        lastPostTime[msg.sender] = block.timestamp;

        for (uint i=0; i<usersLength; i++) {
        // get the score of the user, update the score of the user
        if (entryLeaderBoard[i].user == msg.sender) {
            uint score = entryLeaderBoard[i].score + 1;
            // find where to insert the new score
            if (entryLeaderBoard[i].score < score) {

            // shift leaderboard
            ranking memory currentUser = entryLeaderBoard[i];
            for (uint j=i+1; j<usersLength+1; j++) {
            ranking memory nextUser = entryLeaderBoard[j];
            entryLeaderBoard[j] = currentUser;
            currentUser = nextUser;
            }

            // insert
            entryLeaderBoard[i] = ranking({
            user: msg.sender,
            score: score
            });

        }
        }

        }
    }

    // function to up vote a post
    function upvotePost(uint id) public {
        require(blackList[msg.sender] != true, "You have blackListed");
        AllPosts[id].upVotes = AllPosts[id].upVotes + 1;

        address postAuthor = AllPosts[id].author;
        profile[postAuthor].upVotes = profile[postAuthor].upVotes + 1;
        claimableKarma[postAuthor] = claimableKarma[postAuthor] + 1;
        
        for (uint i=0; i<usersLength; i++) {
        // get the score of the user, update the score of the user
        if (upvotesLeaderBoard[i].user == msg.sender) {
            uint score = upvotesLeaderBoard[i].score + 1;
            // find where to insert the new score
            if (upvotesLeaderBoard[i].score < score) {

            // shift leaderboard
            ranking memory currentUser = upvotesLeaderBoard[i];
            for (uint j=i+1; j<usersLength+1; j++) {
            ranking memory nextUser = upvotesLeaderBoard[j];
            upvotesLeaderBoard[j] = currentUser;
            currentUser = nextUser;
            }

            // insert
            upvotesLeaderBoard[i] = ranking({
            user: msg.sender,
            score: score
            });

        }
        }

        }
    }

    // function to up vote a comment
    function upvoteComment(uint id, uint cId) public {
        require(blackList[msg.sender] != true, "You have blackListed");
       Comment[] memory _comments = comments[id];
        Comment memory comment = _comments[cId];
        comment.upVotes = comment.upVotes + 1;

        address postAuthor = comment.author;
        profile[postAuthor].upVotes = profile[postAuthor].upVotes + 1;
        claimableKarma[postAuthor] = claimableKarma[postAuthor] + 1;

        for (uint i=0; i<usersLength; i++) {
        // get the score of the user, update the score of the user
        if (upvotesLeaderBoard[i].user == msg.sender) {
            uint score = upvotesLeaderBoard[i].score + 1;
            // find where to insert the new score
            if (upvotesLeaderBoard[i].score < score) {

            // shift leaderboard
            ranking memory currentUser = upvotesLeaderBoard[i];
            for (uint j=i+1; j<usersLength+1; j++) {
            ranking memory nextUser = upvotesLeaderBoard[j];
            upvotesLeaderBoard[j] = currentUser;
            currentUser = nextUser;
            }

            // insert
            upvotesLeaderBoard[i] = ranking({
            user: msg.sender,
            score: score
            });

        }
        }

        }

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
        function removeFromBlackList(address user) public {
        require(msg.sender == owner, "You are permitted to perform this function");
        blackList[user] = false;
    }

    // IMPLEMENTING REVENUE DISTRIBUTION

    // function to redeem karma
    function redeemKarma()  returns () {
    
    } 
}