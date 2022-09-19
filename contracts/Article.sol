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

    // the deployment time
    uint deployTime;

    // the price feed to getthe price of matic
    AggregatorV3Interface internal priceFeed;

    // Mapping to track the entry leaderboard
    mapping (uint => mapping (uint => ranking)) entryLeaderBoard;

    // Mapping to track the upvotes leaderboard
    mapping (uint => mapping (uint => ranking)) upvotesLeaderBoard;

    // Mapping to track the headline leaderboard
    mapping (uint => mapping (uint => ranking)) headlineLeaderBoard;

    // Mapping to store the revenue in a week
    mapping (uint => uint) weekrevenue;

    // the number of users
    uint usersLength = 0;

    // the ranking struct
    struct ranking {
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
        deployTime = block.timestamp;
        priceFeed = AggregatorV3Interface(0x572dDec9087154dC5dfBB1546Bb62713147e0Ab0);

    }

    function getMaticPrice() public view returns (int) {
        (
      uint80 roundId,
      int256 price,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
        ) = priceFeed.latestRoundData();
      return price / 1e8;
    }

    // function to sign a user up
    function signUp(string memory profileHash) public {
        profile[msg.sender].profileHash = profileHash; // the profile object has to be stored on IPFS already and the hash returned
        userCategory[msg.sender] = 1; // 1 to denote bronze
        usersLength = usersLength + 1; // updating the numbers of users

    }

    // function to make an entry/post
    function postHeadline(string memory entryHash, string memory topic) public payable {
        int _maticPrice = getMaticPrice();
        uint maticprice = uint(_maticPrice);
        uint headlineFee = (666 * (10 ** 15)) / maticprice;

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
        uint week = getWeek();
        weekrevenue[week] = weekrevenue[week] + msg.value;

    for (uint i=0; i<usersLength; i++) {
      // get the score of the user, update the score of the user
      if (headlineLeaderBoard[week][i].user == msg.sender) {
        uint score = headlineLeaderBoard[week][i].score + 1;
        // find where to insert the new score
        if (headlineLeaderBoard[week][i].score < score) {

        // shift leaderboard
        ranking memory currentUser = headlineLeaderBoard[week][i];
        for (uint j=i+1; j<usersLength+1; j++) {
          ranking memory nextUser = headlineLeaderBoard[week][j];
          headlineLeaderBoard[week][j] = currentUser;
          currentUser = nextUser;
        }

        // insert
        headlineLeaderBoard[week][i] = ranking({
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
    function postEntry(uint id, string memory commentHash) public payable {
        int _maticPrice = getMaticPrice();
        uint maticprice = uint(_maticPrice);
        uint commentFee = (666 * (10 ** 15)) / maticprice;

        require(msg.value == commentFee);
        require(blackList[msg.sender] != true, "You have blackListed");
        require(block.timestamp > lastPostTime[msg.sender] + 1 hours);
        Comment memory c;
        c.author = msg.sender;
        c.commentHash = commentHash;
        c.upVotes = 0;

        comments[id].push(c);
        lastPostTime[msg.sender] = block.timestamp;
        uint week = getWeek();
        weekrevenue[week] = weekrevenue[week] + msg.value;

        for (uint i=0; i<usersLength; i++) {
        // get the score of the user, update the score of the user
        if (entryLeaderBoard[week][i].user == msg.sender) {
            uint score = entryLeaderBoard[week][i].score + 1;
            // find where to insert the new score
            if (entryLeaderBoard[week][i].score < score) {

            // shift leaderboard
            ranking memory currentUser = entryLeaderBoard[week][i];
            for (uint j=i+1; j<usersLength+1; j++) {
            ranking memory nextUser = entryLeaderBoard[week][j];
            entryLeaderBoard[week][j] = currentUser;
            currentUser = nextUser;
            }

            // insert
            entryLeaderBoard[week][i] = ranking({
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
        uint week = getWeek();

        for (uint i=0; i<usersLength; i++) {
        // get the score of the user, update the score of the user
        if (upvotesLeaderBoard[week][i].user == msg.sender) {
            uint score = upvotesLeaderBoard[week][i].score + 1;
            // find where to insert the new score
            if (upvotesLeaderBoard[week][i].score < score) {

            // shift leaderboard
            ranking memory currentUser = upvotesLeaderBoard[week][i];
            for (uint j=i+1; j<usersLength+1; j++) {
            ranking memory nextUser = upvotesLeaderBoard[week][j];
            upvotesLeaderBoard[week][j] = currentUser;
            currentUser = nextUser;
            }

            // insert
            upvotesLeaderBoard[week][i] = ranking({
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
        uint week = getWeek();

        for (uint i=0; i<usersLength; i++) {
        // get the score of the user, update the score of the user
        if (upvotesLeaderBoard[week][i].user == msg.sender) {
            uint score = upvotesLeaderBoard[week][i].score + 1;
            // find where to insert the new score
            if (upvotesLeaderBoard[week][i].score < score) {

            // shift leaderboard
            ranking memory currentUser = upvotesLeaderBoard[week][i];
            for (uint j=i+1; j<usersLength+1; j++) {
            ranking memory nextUser = upvotesLeaderBoard[week][j];
            upvotesLeaderBoard[week][j] = currentUser;
            currentUser = nextUser;
            }

            // insert
            upvotesLeaderBoard[week][i] = ranking({
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

    // function to get the week of the post
    function getWeek() internal view returns (uint week) {
        week = (block.timestamp / deployTime) - (block.timestamp % deployTime);
    }

    // IMPLEMENTING REVENUE DISTRIBUTION

    // function to redeem karma
    function redeemUpvotesRevenue(uint week) public {
        int _maticPrice = getMaticPrice();
        uint maticprice = uint(_maticPrice);
        uint revenue = weekrevenue[week];

        // get the position of the caller on the leaderboard
        address first = upvotesLeaderBoard[week][1].user;
        address second = upvotesLeaderBoard[week][2].user;
        address third = upvotesLeaderBoard[week][3].user;
        address fourth = upvotesLeaderBoard[week][4].user;
        address fifth = upvotesLeaderBoard[week][5].user;

        bool sixthtotenth = isSixthUpvotes(week);
        bool eleventhtotwentieth = isTenthUpvotes(week);

        uint firstRev = (666 * (10 ** 18)) / maticprice;
        uint secondRev = (1665 * (10 ** 18)) / maticprice;
        uint thirdRev = (3330 * (10 ** 18)) / maticprice;
        uint fourthRev = (6660 * (10 ** 18)) / maticprice;



        if (revenue > firstRev && revenue < secondRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((50 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((30 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((20 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((15 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((5 * (10 ** 18)) / maticprice);
            }

        }
        else if(revenue > secondRev && revenue < thirdRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((100 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((60 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((30 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((20 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((5 * (10 ** 18)) / maticprice);
            }
        }
        else if (revenue > thirdRev && revenue < fourthRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((250 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((125 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((80 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((60 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((25 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
        }
        else if (revenue > fourthRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((500 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((250 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((150 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((100 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((70 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((25 * (10 ** 18)) / maticprice);
            }
        }

    }

    // function to claim entries revenue
        function redeemEntriesRevenue(uint week) public {
        int _maticPrice = getMaticPrice();
        uint maticprice = uint(_maticPrice);
        uint revenue = weekrevenue[week];

        // get the position of the caller on the leaderboard
        address first = entryLeaderBoard[week][1].user;
        address second = entryLeaderBoard[week][2].user;
        address third = entryLeaderBoard[week][3].user;
        address fourth = entryLeaderBoard[week][4].user;
        address fifth = entryLeaderBoard[week][5].user;

        bool sixthtotenth = isSixthUpvotes(week);
        bool eleventhtotwentieth = isTenthUpvotes(week);

        uint firstRev = (666 * (10 ** 18)) / maticprice;
        uint secondRev = (1665 * (10 ** 18)) / maticprice;
        uint thirdRev = (3330 * (10 ** 18)) / maticprice;
        uint fourthRev = (6660 * (10 ** 18)) / maticprice;



        if (revenue > firstRev && revenue < secondRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((50 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((30 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((20 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((15 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((5 * (10 ** 18)) / maticprice);
            }

        }
        else if(revenue > secondRev && revenue < thirdRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((100 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((60 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((30 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((20 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((5 * (10 ** 18)) / maticprice);
            }
        }
        else if (revenue > thirdRev && revenue < fourthRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((250 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((125 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((80 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((60 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((25 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
        }
        else if (revenue > fourthRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((500 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((250 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((150 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((100 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((70 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((25 * (10 ** 18)) / maticprice);
            }
        }

    }

    // function to claim headlines revenue
    function redeemHeadlinesRevenue(uint week) public {
        uint category = userCategory[msg.sender];
        require(category == 3, "You are not a gold member");
        int _maticPrice = getMaticPrice();
        uint maticprice = uint(_maticPrice);
        uint revenue = weekrevenue[week];

        // get the position of the caller on the leaderboard
        address first = entryLeaderBoard[week][1].user;
        address second = entryLeaderBoard[week][2].user;
        address third = entryLeaderBoard[week][3].user;
        address fourth = entryLeaderBoard[week][4].user;
        address fifth = entryLeaderBoard[week][5].user;

        bool sixthtotenth = isSixthUpvotes(week);
        bool eleventhtotwentieth = isTenthUpvotes(week);

        uint firstRev = (666 * (10 ** 18)) / maticprice;
        uint secondRev = (1665 * (10 ** 18)) / maticprice;
        uint thirdRev = (3330 * (10 ** 18)) / maticprice;
        uint fourthRev = (6660 * (10 ** 18)) / maticprice;



        if (revenue > firstRev && revenue < secondRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((50 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((30 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((20 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((15 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((5 * (10 ** 18)) / maticprice);
            }

        }
        else if(revenue > secondRev && revenue < thirdRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((100 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((60 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((30 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((20 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((5 * (10 ** 18)) / maticprice);
            }
        }
        else if (revenue > thirdRev && revenue < fourthRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((250 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((125 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((80 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((60 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((25 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((10 * (10 ** 18)) / maticprice);
            }
        }
        else if (revenue > fourthRev) {
            if (first == msg.sender) {
                payable(msg.sender).transfer((500 * (10 ** 18)) / maticprice);
            } else if (second == msg.sender) {
                payable(msg.sender).transfer((250 * (10 ** 18)) / maticprice);
            }
            else if (third == msg.sender) {
                payable(msg.sender).transfer((150 * (10 ** 18)) / maticprice);
            }
            else if (fourth == msg.sender) {
                payable(msg.sender).transfer((100 * (10 ** 18)) / maticprice);
            }
            else if (fifth == msg.sender) {
                payable(msg.sender).transfer((70 * (10 ** 18)) / maticprice);
            }
            else if (sixthtotenth == true) {
                payable(msg.sender).transfer((40 * (10 ** 18)) / maticprice);
            }
            else if (eleventhtotwentieth == true) {
                payable(msg.sender).transfer((25 * (10 ** 18)) / maticprice);
            }
        }

    }

    // function to know the position of the caller 
    function isSixthUpvotes(uint week) internal view returns(bool isSixth) {
        for (uint i = 6; i < 11; i++) {
            if(upvotesLeaderBoard[week][i].user == msg.sender) {
                isSixth = true;
            }
            else {
                isSixth = false;
            }
        }
    }

    function isTenthUpvotes(uint week) internal view returns(bool isSixth) {
        for (uint i = 11; i < 21; i++) {
            if(upvotesLeaderBoard[week][i].user == msg.sender) {
                isSixth = true;
            }
            else {
                isSixth = false;
            }
        }
    }

    function isSixthEntries(uint week) internal view returns(bool isSixth) {
        for (uint i = 6; i < 11; i++) {
            if(entryLeaderBoard[week][i].user == msg.sender) {
                isSixth = true;
            }
            else {
                isSixth = false;
            }
        }
    }

    function isTenthEntries(uint week) internal view returns(bool isSixth) {
        for (uint i = 11; i < 21; i++) {
            if(entryLeaderBoard[week][i].user == msg.sender) {
                isSixth = true;
            }
            else {
                isSixth = false;
            }
        }
    }

        function isSixthHeadlines(uint week) internal view returns(bool isSixth) {
        for (uint i = 6; i < 11; i++) {
            if(headlineLeaderBoard[week][i].user == msg.sender) {
                isSixth = true;
            }
            else {
                isSixth = false;
            }
        }
    }

    function isTenthHeadlines(uint week) internal view returns(bool isSixth) {
        for (uint i = 11; i < 21; i++) {
            if(headlineLeaderBoard[week][i].user == msg.sender) {
                isSixth = true;
            }
            else {
                isSixth = false;
            }
        }
    }
}

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}