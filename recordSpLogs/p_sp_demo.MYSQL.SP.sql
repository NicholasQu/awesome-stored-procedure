DROP procedure IF EXISTS `p_demo`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `p_demo`()
label_entry:BEGIN
   /*
    功能说明：
        该存储过程的主要功能、用途的描述；

    参数说明：
        输入输出参数、类型、规则说明；

    运行频度：

    更新历史：
        2019.8.4 By 曲健: XXXXXXXXXXXXXXXXXXX；
        2019.7.4 By 曲健: YYYYYYYYYYYYYYYYYYY；
    */
    /* 变量声明区 */

    /* 异常处理区 */
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
   
        GET DIAGNOSTICS CONDITION 1 
        @sqlstat = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @errmsg = MESSAGE_TEXT;

        /*输出异常日志*/
        call `db_admin`.`logSpErrAndEnd`(
                            'p_demo', 
                            CONCAT('SP运行异常, SQLSTATE:', @sqlstat, 
                                        ', ERRNO:', @errno, 
                                        ', ERR_MSG:', @errmsg),
                            @sp_exec_no);
        /*
        若该异常发生可以继续运行下去，不终止SP，则调用这个方法
        call `db_admin`.`logSpErrAndContinue`(
                            'p_demo', 
                            CONCAT('SP运行异常, SQLSTATE:', @sqlstat, 
                                        ', ERRNO:', @errno, 
                                        ', ERR_MSG:', @errmsg)
                            @sp_exec_no);
        */
    END;

    /* 1. SP启动 & 检查自身不重复执行 & 检查依赖的SP是否运行成功 */
    /* 10 = 10分钟的SP运行频度 */
    call `db_admin`.`logSpStart`('p_demo', 'demo start', 10, @sp_exec_no);
    /* 1. 假设依赖 sp_cash_loan_monthly 的运行成功(不能有任何Err日志)
    call `db_admin`.`logSpStartAndCheck`('p_demo','demo start & check', 10,
                                'sp_cash_loan_monthly', '2019-08-26', now(), @sp_exec_no);
    */
    if @sp_exec_no is null THEN
        leave label_entry;
    end if;
    
    
    /* 存储过程主体逻辑... */
    
    /* 2. SP调试信息打印 */
    call logSpInfo('p_demo', '开始复制数据', @sp_exec_no);
    
    /* 存储过程主体逻辑... */
    

    /* 3. SP结束标记 */
    call `db_admin`.`logSpEnd`('p_demo', '运行结束', @sp_exec_no);
END;