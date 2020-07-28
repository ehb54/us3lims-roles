-- MySQL dump 10.14  Distrib 5.5.64-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: 
-- ------------------------------------------------------
-- Server version	5.5.64-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


--
-- Current Database: `uslims3_global`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `uslims3_global` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `uslims3_global`;

--
-- Table structure for table `investigators`
--

DROP TABLE IF EXISTS `investigators`;
CREATE TABLE `investigators` (
  `invGlobal_ID` int(11) NOT NULL AUTO_INCREMENT,
  `InvestigatorID` int(11) NOT NULL,
  `Investigator_Name` varchar(61) DEFAULT NULL,
  `db` varchar(30) DEFAULT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `Signup` datetime DEFAULT '0000-00-00 00:00:00',
  `LastLogin` datetime DEFAULT '0000-00-00 00:00:00',
  `Userlevel` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`invGlobal_ID`)
) ENGINE=MyISAM AUTO_INCREMENT=4489 DEFAULT CHARSET=latin1;

--
-- Table structure for table `submissions`
--

DROP TABLE IF EXISTS `submissions`;
CREATE TABLE `submissions` (
  `HPCGlobal_ID` int(11) NOT NULL AUTO_INCREMENT,
  `HPCAnalysis_ID` int(11) NOT NULL,
  `db` varchar(30) DEFAULT NULL,
  `DateTime` datetime DEFAULT NULL,
  `EndDateTime` datetime DEFAULT NULL,
  `CPUTime` double DEFAULT NULL,
  `Cluster_Name` varchar(80) DEFAULT NULL,
  `CPU_Number` int(11) DEFAULT NULL,
  `Result_Count` int(11) DEFAULT '1',
  `InvestigatorID` int(11) NOT NULL,
  `Investigator_Name` varchar(61) DEFAULT NULL,
  `SubmitterID` int(11) NOT NULL,
  `Submitter_Name` varchar(61) DEFAULT NULL,
  PRIMARY KEY (`HPCGlobal_ID`)
) ENGINE=MyISAM AUTO_INCREMENT=302167 DEFAULT CHARSET=latin1;

--
-- Dumping events for database 'uslims3_global'
--

--
-- Dumping routines for database 'uslims3_global'
--

