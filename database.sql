SET FOREIGN_KEY_CHECKS=0;

-- ----------------------------
-- Table structure for flow
-- ----------------------------
DROP TABLE IF EXISTS `flow`;
CREATE TABLE `flow` (
  `date` datetime DEFAULT NULL COMMENT 'Дата',
  `type` enum('Поступление','Реализация','Возврат рабочий','Возврат не рабочий','Корректировка остатка') NOT NULL DEFAULT 'Реализация' COMMENT 'Действие',
  `storage` enum('n','b') NOT NULL DEFAULT 'n' COMMENT 'Склад',
  `total` float DEFAULT NULL COMMENT 'Итого',
  `cash` float DEFAULT NULL COMMENT 'Передано',
  `comment` varchar(255) DEFAULT NULL COMMENT 'Комментарий',
  `author` varchar(64) DEFAULT NULL COMMENT 'Автор',
  `id` int(11) NOT NULL AUTO_INCREMENT,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=141 DEFAULT CHARSET=utf8 COMMENT='Движения';

-- ----------------------------
-- Table structure for flow_product
-- ----------------------------
DROP TABLE IF EXISTS `flow_product`;
CREATE TABLE `flow_product` (
  `flow_id` int(11) NOT NULL,
  `product_name` varchar(255) NOT NULL COMMENT 'Продукт',
  `product_id` int(11) NOT NULL,
  `qty` float(10,4) NOT NULL COMMENT 'Количество',
  `price_out_r` float(10,2) DEFAULT NULL COMMENT 'Отпускная цена, руб',
  `total_rub` float(10,2) DEFAULT NULL COMMENT 'Итого, руб',
  `price_in_usd` float(10,2) NOT NULL COMMENT 'Цена поступления, USD',
  `price_out_usd` float(10,2) DEFAULT NULL COMMENT 'Цена реализации, USD',
  `total_usd` float(10,2) DEFAULT NULL COMMENT 'Итого USD',
  `weight` int(11) DEFAULT NULL COMMENT 'Порядок',
  `manualPrice` bit(1) DEFAULT NULL COMMENT 'Цена корректирована',
  KEY `flow_product__product` (`product_name`,`product_id`),
  KEY `flow_product__flow` (`flow_id`),
  CONSTRAINT `flow_product__flow` FOREIGN KEY (`flow_id`) REFERENCES `flow` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `flow_product__product` FOREIGN KEY (`product_name`, `product_id`) REFERENCES `product` (`name`, `id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8 ROW_FORMAT=DYNAMIC;

-- ----------------------------
-- Table structure for product
-- ----------------------------
DROP TABLE IF EXISTS `product`;
CREATE TABLE `product` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `section` enum('Section 1', 'Section 2', 'Section 3') DEFAULT NULL COMMENT 'Секция',
  `name` varchar(255) DEFAULT NULL,
  `price` float(10,2) DEFAULT NULL,
  `barcode` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`,`id`)
) ENGINE=InnoDB AUTO_INCREMENT=503 DEFAULT CHARSET=utf8 COMMENT='Номенклатура';

-- ----------------------------
-- Table structure for rates
-- ----------------------------
DROP TABLE IF EXISTS `rates`;
CREATE TABLE `rates` (
  `date` date NOT NULL,
  `rate` float(10,4) NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Курсы';


-- ----------------------------
-- Function structure for get_signed_qty
-- ----------------------------
DROP FUNCTION IF EXISTS `get_signed_qty`;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `get_signed_qty`(`qty` float,`type` char(255)) RETURNS float
BEGIN
	#Routine body goes here...
  IF type IN ('Поступление', 'Возврат рабочий', 'Возврат не рабочий') THEN
    RETURN qty;
	ELSE
		RETURN qty*-1;
	END IF;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for is_customer_interaction
-- ----------------------------
DROP FUNCTION IF EXISTS `is_customer_interaction`;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `is_customer_interaction`(`type` char(255)) RETURNS tinyint(1)
BEGIN
	#Routine body goes here...
  IF NOT type IN ('Поступление', 'Корректировка остатка') THEN
    RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for is_return
-- ----------------------------
DROP FUNCTION IF EXISTS `is_return`;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `is_return`(`type` char(255)) RETURNS tinyint(1)
BEGIN
	#Routine body goes here...
  IF type IN ('Возврат рабочий', 'Возврат не рабочий') THEN
    RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for is_selling
-- ----------------------------
DROP FUNCTION IF EXISTS `is_selling`;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `is_selling`(`type` char(255)) RETURNS tinyint(1)
BEGIN
	#Routine body goes here...
  IF type IN ('Реализация') THEN
    RETURN TRUE;
	ELSE
		RETURN FALSE;
	END IF;
END
;;
DELIMITER ;

-- ----------------------------
-- Function structure for is_voucher
-- ----------------------------
DROP FUNCTION IF EXISTS `is_voucher`;
DELIMITER ;;
CREATE DEFINER=`root`@`localhost` FUNCTION `is_voucher`(`voucher` char(255)) RETURNS tinyint(1)
BEGIN
	#Routine body goes here...
  RETURN voucher = 'Чек';
END
;;
DELIMITER ;
DROP TRIGGER IF EXISTS `flow_OnInsert`;
DELIMITER ;;
CREATE TRIGGER `flow_OnInsert` BEFORE INSERT ON `flow` FOR EACH ROW BEGIN
SET NEW.date = IFNULL(NEW.date, NOW());
SET NEW.author = user();
END
;;
DELIMITER ;

-- ----------------------------
-- View structure for day_sales
-- ----------------------------
DROP VIEW IF EXISTS `day_sales`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `day_sales` AS select year(`flow`.`date`) AS `Год`,month(`flow`.`date`) AS `Месяц`,dayofmonth(`flow`.`date`) AS `День`,(dayofweek(`flow`.`date`) - 1) AS `День недели`,`flow`.`storage` AS `Склад`,sum(if(`is_selling`(`flow`.`type`),(`flow_product`.`price_in_usd` * `flow_product`.`qty`),0)) AS `Себестоимость реализованной, USD`,sum(if(`is_selling`(`flow`.`type`),`flow_product`.`total_usd`,0)) AS `Цена реализованной, USD`,(sum(if(`is_selling`(`flow`.`type`),(`flow_product`.`price_out_usd` * `flow_product`.`qty`),0)) - sum(if(`is_selling`(`flow`.`type`),(`flow_product`.`price_in_usd` * `flow_product`.`qty`),0))) AS `Выручка, USD`,sum(if(`is_return`(`flow`.`type`),(`flow_product`.`price_in_usd` * `flow_product`.`qty`),0)) AS `Себестоимость возвращенной, USD`,sum(if(`is_return`(`flow`.`type`),(`flow_product`.`price_out_usd` * `flow_product`.`qty`),0)) AS `Цена возвращенной, USD`,(sum(if(`is_return`(`flow`.`type`),(`flow_product`.`price_out_usd` * `flow_product`.`qty`),0)) - sum(if(`is_return`(`flow`.`type`),(`flow_product`.`price_in_usd` * `flow_product`.`qty`),0))) AS `Потеря, USD` from (`flow` join `flow_product` on((`flow_product`.`flow_id` = `flow`.`id`))) where `is_customer_interaction`(`flow`.`type`) group by year(`flow`.`date`),month(`flow`.`date`),dayofmonth(`flow`.`date`),`flow`.`storage`,`flow`.`date` order by year(`flow`.`date`),month(`flow`.`date`),dayofmonth(`flow`.`date`),`flow`.`storage` ;

-- ----------------------------
-- View structure for month_sales
-- ----------------------------
DROP VIEW IF EXISTS `month_sales`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `month_sales` AS select `day_sales`.`Год` AS `Год`,`day_sales`.`Месяц` AS `Месяц`,`day_sales`.`Склад` AS `Склад`,sum(`day_sales`.`Себестоимость реализованной, USD`) AS `Себестоимость реализованной, USD`,sum(`day_sales`.`Цена реализованной, USD`) AS `Цена реализованной, USD`,sum(`day_sales`.`Выручка, USD`) AS `Выручка, USD`,sum(`day_sales`.`Себестоимость возвращенной, USD`) AS `Стоимость возвращенной, USD`,sum(`day_sales`.`Цена возвращенной, USD`) AS `Цена возвращенной, USD`,sum(`day_sales`.`Потеря, USD`) AS `Потеря, USD` from `day_sales` group by `day_sales`.`Склад`,`day_sales`.`Месяц`,`day_sales`.`Год` ;

-- ----------------------------
-- View structure for product_flow
-- ----------------------------
DROP VIEW IF EXISTS `product_flow`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `product_flow` AS select `flow`.`date` AS `date`,`flow`.`id` AS `id`,`flow`.`type` AS `type`,`flow`.`storage` AS `storage`,`flow_product`.`product_name` AS `product_name`,`flow_product`.`qty` AS `qty`,`flow_product`.`price_out_r` AS `price_out_r`,`flow_product`.`price_in_usd` AS `price_in_usd`,`flow_product`.`total_rub` AS `total_rub`,`flow_product`.`price_out_usd` AS `price_out_usd`,`flow_product`.`total_usd` AS `total_usd`,`flow_product`.`manualPrice` AS `manualPrice`,`flow_product`.`product_id` AS `product_id`,`flow`.`comment` AS `comment` from (`flow_product` join `flow` on((`flow_product`.`flow_id` = `flow`.`id`))) ;

-- ----------------------------
-- View structure for remains
-- ----------------------------
DROP VIEW IF EXISTS `remains`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `remains` AS select `flow`.`storage` AS `storage`,`product`.`section` AS `section`,`flow_product`.`product_name` AS `product_name`,`flow_product`.`price_in_usd` AS `price_in_usd`,sum(if((`flow`.`type` <> 'Возврат не рабочий'),`get_signed_qty`(`flow_product`.`qty`,`flow`.`type`),0)) AS `balance`,sum(if((`flow`.`type` = 'Возврат не рабочий'),`get_signed_qty`(`flow_product`.`qty`,`flow`.`type`),0)) AS `balance_broken`,`product`.`barcode` AS `barcode` from ((`flow` join `flow_product` on((`flow_product`.`flow_id` = `flow`.`id`))) join `product` on(((`flow_product`.`product_name` = `product`.`name`) and (`flow_product`.`product_id` = `product`.`id`)))) group by `flow`.`storage`,`flow_product`.`product_name`,`flow_product`.`product_id`,`flow_product`.`price_in_usd`,`product`.`barcode` order by `flow`.`storage`,`flow_product`.`product_name` ;

-- ----------------------------
-- View structure for remains_common
-- ----------------------------
DROP VIEW IF EXISTS `remains_common`;
CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `remains_common` AS select `remains`.`section` AS `section`,`remains`.`product_name` AS `product_name`,`remains`.`price_in_usd` AS `price_in_usd`,sum(`remains`.`balance`) AS `balance`,sum(`remains`.`balance_broken`) AS `Остаток поломанных`,`remains`.`barcode` AS `barcode` from `remains` group by `remains`.`section`,`remains`.`product_name`,`remains`.`price_in_usd`,`remains`.`barcode` ;

