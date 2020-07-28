-- -----------------------------------------------------
-- Table notice
-- -----------------------------------------------------
DROP TABLE IF EXISTS notice ;

CREATE  TABLE IF NOT EXISTS notice (
  id int(11) NOT NULL AUTO_INCREMENT ,
  type enum('info','warn','crit'),
  revision VARCHAR(12) NULL DEFAULT NULL,
  message LONGTEXT NULL DEFAULT NULL ,
  lastUpdated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP ,
  PRIMARY KEY (id) )
ENGINE = InnoDB;
