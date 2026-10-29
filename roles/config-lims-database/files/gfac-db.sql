-- MySQL dump 10.13  Distrib 5.1.73, for redhat-linux-gnu (x86_64)
--
-- Host: localhost    Database: 
-- ------------------------------------------------------
-- Server version	5.1.73-log

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
-- Current Database: `gfac`
--

CREATE DATABASE /*!32312 IF NOT EXISTS*/ `gfac` /*!40100 DEFAULT CHARACTER SET latin1 */;

USE `gfac`;

--
-- Table structure for table `analysis`
--

DROP TABLE IF EXISTS `analysis`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `analysis` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `gfacID` varchar(80) DEFAULT NULL,
  `cluster` varchar(64) DEFAULT NULL,
  `metaschedulerClusterExecuting` varchar(64) DEFAULT NULL,
  `us3_db` varchar(32) DEFAULT NULL,
  `autoflowAnalysisID` int(11) DEFAULT NULL,
  `stdout` longtext,
  `stderr` longtext,
  `tarfile` mediumblob,
  `status` enum('SUBMITTED','SUBMIT_TIMEOUT','RUNNING','RUN_TIMEOUT','DATA','DATA_TIMEOUT','COMPLETE','CANCELLED','CANCELED','FAILED','FAILED_DATA','ERROR','FINISHED','DONE') DEFAULT 'SUBMITTED',
  `queue_msg` text,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=414 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `cluster_status`
--

DROP TABLE IF EXISTS `cluster_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `cluster_status` (
  `cluster` varchar(120) NOT NULL,
  `queued` int(11) DEFAULT NULL,
  `running` int(11) DEFAULT NULL,
  `status` enum('up','down','warn','unknown') DEFAULT 'up',
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `queue_messages`
--

DROP TABLE IF EXISTS `queue_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `queue_messages` (
  `messageID` int(11) NOT NULL AUTO_INCREMENT,
  `analysisID` int(11) NOT NULL,
  `message` text,
  `time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`messageID`)
) ENGINE=MyISAM AUTO_INCREMENT=5287341 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `metascheduler_decision` and `cluster_status_nudge`
-- (gridctl's pick_cluster()): without them a host built fresh by this role
-- has no audit trail and loses its double-booking protection for a
-- configured pool. CREATE TABLE IF NOT EXISTS, same as both tables' own
-- source files (home/us3/lims/bin/gridctl/metascheduler_decision_table.sql
-- and cluster_status_nudge_table.sql in the uslims_stack aggregator repo)
-- and us3_sql's gfac.sql fresh-install schema -- purely additive, so
-- re-running this file leaves an existing table and its data alone.
--

CREATE TABLE IF NOT EXISTS `metascheduler_decision` (
`id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'Unique decision ID',
`pseudo_cluster` varchar(120) NOT NULL COMMENT 'Metascheduler pool name that was resolved',
`chosen` varchar(120) DEFAULT NULL COMMENT 'Real cluster chosen, or NULL when none was eligible',
`reason` varchar(255) DEFAULT NULL COMMENT 'pick_cluster() reason string for the outcome',
`tier` varchar(32) DEFAULT NULL COMMENT 'Tier the chosen cluster belongs to (local/national/...), NULL when nothing chosen',
`scores` text COMMENT 'JSON-encoded pick_cluster() scores for every candidate, for full post-hoc diagnosis',
`time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this decision was made',
PRIMARY KEY (`id`),
KEY `pseudo_cluster_time` (`pseudo_cluster`, `time`),
KEY `time` (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci
  COMMENT='Queryable history of metascheduler pick_cluster() decisions';

CREATE TABLE IF NOT EXISTS `cluster_status_nudge` (
`id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Unique nudge ID',
`cluster` varchar(64) NOT NULL COMMENT 'Real cluster this decision was nudged onto',
`time` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'When this decision was made',
PRIMARY KEY (`id`),
KEY `cluster_time` (`cluster`, `time`),
KEY `time` (`time`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci
  COMMENT='Short-lived pick_cluster_reserve() load nudges, independent of the real cluster_status probe';

