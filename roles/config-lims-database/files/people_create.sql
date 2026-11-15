--
-- Table structure for table `people`
--

-- DROP TABLE IF EXISTS `people`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `people` (
  `personID` int(11) NOT NULL AUTO_INCREMENT,
  `fname` varchar(30) DEFAULT NULL,
  `lname` varchar(30) DEFAULT NULL,
  `address` varchar(255) DEFAULT NULL,
  `city` varchar(30) DEFAULT NULL,
  `state` char(2) DEFAULT NULL,
  `zip` varchar(10) DEFAULT NULL,
  `country` varchar(64) DEFAULT NULL,
  `phone` varchar(24) DEFAULT NULL,
  `email` varchar(63) NOT NULL,
  `organization` varchar(45) DEFAULT NULL,
  `username` varchar(80) DEFAULT NULL,
  `password` varchar(80) NOT NULL,
  `activated` tinyint(1) NOT NULL DEFAULT '0',
  `account_enabled` tinyint(1) unsigned NOT NULL DEFAULT '1',
  `signup` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `lastLogin` datetime DEFAULT NULL,
  `userlevel` tinyint(4) NOT NULL DEFAULT '0',
  PRIMARY KEY (`personID`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=14 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

