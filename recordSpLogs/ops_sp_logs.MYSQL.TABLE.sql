DROP TABLE IF EXISTS `ops_sp_logs`;
CREATE TABLE `ops_sp_logs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `sp_exec_no` bigint(20) NOT NULL COMMENT '存储过程本次执行批次号',
  `sp_name` varchar(100) NOT NULL COMMENT '存储过程名称',
  `event_type` varchar(40) NOT NULL COMMENT '事件类型: SP-Start、SP-Succ、SP-Fail、SP-Step',
  `event_desc` varchar(500) DEFAULT NULL COMMENT '事件描述',
  `log_level` varchar(10) NOT NULL COMMENT '日志级别：WARN-告警，INFO-正常日志,ERR-错误日志',
  `log_time` datetime NOT NULL COMMENT '日志记录时间',
  `running_state` tinyint(4) NOT NULL COMMENT 'SP运行状态：0-运行中 1-运行完成',
  PRIMARY KEY (`id`),
  KEY `IDX_SP_LOG_EXEC_NO` (`sp_exec_no`) USING BTREE,
  KEY `IDX_SP_LOG_LOG_TIME` (`sp_name`,`log_time`) USING BTREE
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8 COMMENT='存储过程运行日志，字符字段全部用小写存储，方便检索';
