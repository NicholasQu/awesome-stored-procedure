/**********************************************
 *  建表
 **********************************************/
DROP TABLE IF EXISTS `ops_seq`;
CREATE TABLE `ops_seq` (
  `seq_no` bigint(20) NOT NULL AUTO_INCREMENT,
  `seq_type` varchar(10) DEFAULT NULL COMMENT '序列号类型',
  PRIMARY KEY (`seq_no`),
  KEY `IDX_OPS_SEQ_TYPE` (`seq_type`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;


/**********************************************
 *  自定义函数
 **********************************************/
DROP FUNCTION IF EXISTS `getSeqNo`;

DELIMITER $$
CREATE DEFINER=`nicholas.qu`@`%` FUNCTION `getSeqNo`
(
    in_seq_type varchar(5)
)
RETURNS bigint
BEGIN
    /*
    说明：
    根据序号类别，获取全局自增序号。
    不同类别的交叉运行会导致序号跳空，该SP不保证统一类别内的连续性。

    更新历史：
    Nicholas Qu   2019/08/22   初始
    */

    DECLARE V_SEQ_NO_MIN    bigint;
    DECLARE V_SEQ_NO_LAST   bigint;

    insert into ops_seq(seq_no, seq_type) values(null, in_seq_type);
    select last_insert_id() into V_SEQ_NO_LAST;

    select ifnull(min(seq_no),0) into V_SEQ_NO_MIN from ops_seq where seq_type = in_seq_type;

    return V_SEQ_NO_LAST - V_SEQ_NO_MIN + 1;
END

/**********************************************
 *  使用示例
 **********************************************/
select getSeqNo('mall'), getSeqNo('pay');