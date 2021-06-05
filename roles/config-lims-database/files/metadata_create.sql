-- Table structure for table `metadata`
--

-- DROP TABLE IF EXISTS `metadata`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `metadata` (
  `metadataID` int(11) NOT NULL AUTO_INCREMENT,
  `institution` varchar(255) DEFAULT NULL,
  `inst_abbrev` varchar(10) DEFAULT NULL,
  `dbname` varchar(30) DEFAULT NULL,
  `dbuser` varchar(30) DEFAULT NULL,
  `dbpasswd` varchar(30) DEFAULT NULL,
  `dbhost` varchar(60) DEFAULT NULL,
  `limshost` varchar(60) DEFAULT NULL,
  `secure_user` varchar(30) DEFAULT NULL,
  `secure_pw` varchar(30) DEFAULT NULL,
  `admin_fname` varchar(30) DEFAULT NULL,
  `admin_lname` varchar(30) DEFAULT NULL,
  `admin_email` varchar(128) NOT NULL,
  `admin_pw` varchar(80) NOT NULL,
  `lab_name` text,
  `lab_contact` text,
  `location` varchar(255) NOT NULL DEFAULT '',
  `instrument_name` text,
  `instrument_serial` text,
  `status` enum('pending','denied','completed') DEFAULT 'pending',
  `updateTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`metadataID`)
) ENGINE=InnoDB AUTO_INCREMENT=130 DEFAULT CHARSET=latin1;
