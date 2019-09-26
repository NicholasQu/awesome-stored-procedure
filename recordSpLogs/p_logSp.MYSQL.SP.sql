DROP procedure IF EXISTS `p_logSp`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `p_logSp`(
    in    in_sp_name        varchar(100),
    in    in_event_type     varchar(40),
    in    in_event_desc     varchar(500),
    in    in_log_level      varchar(10),
    in    in_running_state  tinyint,
    inout inout_sp_exec_no  bigint
    )
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 记录Sp的运行日志(全部用小写字母存储)
     *
     * in_sp_name           输入        varchar(100)    必输，需要记录日志的当前运行SP名称
     * in_event_type        输入        varchar(40)     必输，事件类型，可自定义抽象如 SpStart SpEnd 等
     * in_event_desc        输入        varchar(500)    可选，事件详情，可自定义输入500字以内的文本
     * in_log_level         输入        varchar(10)     必输，日志级别，INFO/WARN/ERR/CHK(检查日志)
     * in_running_state     输入        tinyint         必输，SP运行状态，0-运行中 1-运行完毕 -99检查类日志
     * inout_sp_exec_no     输入输出     bigint          SP本次运行的唯一运行编号
     * ========================================== */
    
    /* 捕获异常 打印堆栈 以防传入的参数出现校验性错误*/
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1 
        @sqlstat = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @errmsg = MESSAGE_TEXT;

        /*EXCEPTION*/
        insert into ops_sp_logs
            (sp_exec_no, sp_name, event_type, 
            event_desc, 
            log_level, log_time, running_state) 
        values
            (inout_sp_exec_no, 'p_logSp', 'sperr', 
            CONCAT(in_sp_name, ' ', sp_exec_no, 
                    ' 打印日志异常, SQLSTATE:', @sqlstat, 
                    ', ERRNO:', @errno, 
                    ', ERR_MSG:', @errmsg), 
            'err', now(), 1);
    END;

    select ifnull(inout_sp_exec_no, CAST(DATE_FORMAT(now(),'%Y%m%d') AS SIGNED) * 100000000 + getSeqNo('logsp'))
    into inout_sp_exec_no;

    select ifnull(in_log_level, 'info') into in_log_level;

    insert into ops_sp_logs
    (sp_exec_no, sp_name, event_type, event_desc, log_level, log_time, running_state) 
    values
    (inout_sp_exec_no, left(lower(in_sp_name),100), left(lower(in_event_type),40), 
    left(in_event_desc,200), lower(in_log_level), now(), in_running_state);
END;


DROP procedure IF EXISTS `logSpStart`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `logSpStart`(
    in    in_sp_name        varchar(100),
    in    in_event_desc     varchar(500),
    in    in_event_interval bigint,
    inout inout_sp_exec_no  bigint
    )
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 记录Sp开始运行前的日志
     *
     * in_sp_name           输入        varchar(100)    必输，需要记录日志的当前运行SP名称
     * in_event_desc        输入        varchar(500)    可选，事件详情，可自定义输入200字以内的文本
     * in_event_interval    输入        bigint          必输，运行SP的event的时间间隔,单位分钟
     * inout_sp_exec_no     输入输出     bigint          SP本次运行的唯一运行编号, 为空则不应该继续。
     * ========================================== */
    call logSpStartAndCheck(in_sp_name, in_event_desc, in_event_interval,
                null,null,null, inout_sp_exec_no);
END;

DROP procedure IF EXISTS `logSpStartAndCheck`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `logSpStartAndCheck`(
    in    in_sp_name            varchar(100),
    in    in_event_desc         varchar(500),
    in    in_event_interval     bigint,
    in    in_check_sp_name      varchar(100),
    in    in_check_from_time    datetime,
    in    in_check_to_time      datetime,
    inout inout_sp_exec_no      bigint
    )
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 记录Sp开始运行前的日志
     *
     * in_sp_name           输入        varchar(100)    必输，需要记录日志的当前运行SP名称
     * in_event_desc        输入        varchar(500)    可选，事件详情，可自定义输入200字以内的文本
     * in_event_interval    输入        bigint          必输，运行SP的event的时间间隔,单位分钟
     * in_check_sp_name     输入        varchar(100)    必输，依赖的SP名称
     * in_check_from_time   输入        datetime        必输，依赖SP必须运行成功，所需判断时间窗口的开始时间
     * in_check_to_time     输入        datetime        必输，依赖SP必须运行成功，所需判断时间窗口的结束时间
     * inout_sp_exec_no     输入输出     bigint          SP本次运行的唯一运行编号, 为空则不应该继续。
     * ========================================== */
    DECLARE V_MEET_CONDITIONS tinyint; 
    DECLARE V_CHECK_PASS      tinyint default 1;

    /*先检查自己不要跟自己冲突, 若自身重复执行，记录检查日志后跳出*/
    select hasSpSelfRunMeanwhile(in_sp_name, in_event_interval) into V_MEET_CONDITIONS;
    IF V_MEET_CONDITIONS > 0 THEN
        call p_logSp(in_sp_name, 'SpCheck-SelfCross', 
                        CONCAT('时间间隔(分):', in_event_interval, ', SP自身还在运行中，不要重复执行!'), 
                        'chk', -99, inout_sp_exec_no);
        
        select null into inout_sp_exec_no;
        select 0 into V_CHECK_PASS;
    ELSEIF in_check_sp_name is not null AND length(trim(in_check_sp_name)) > 0 THEN
        /*检查依赖的SP是否成功运行完毕，若未成功，则记录检查日志后跳出*/
        select isSpEndSucc(in_check_sp_name, in_check_from_time, in_check_to_time) 
        into V_MEET_CONDITIONS;

        IF V_MEET_CONDITIONS = 0 THEN
            call p_logSp(in_sp_name, 'SpCheck-NotEndSucc', 
                            CONCAT('检查依赖的SP[', in_check_sp_name,
                                    ']从',in_check_from_time,'到', in_check_to_time,
                                    ' 未成功运行！无法继续，需告警！'), 
                            'chk', -99, inout_sp_exec_no);
            
            select null into inout_sp_exec_no;
            select 0 into V_CHECK_PASS;
        END IF;
    END IF;
    
    if V_CHECK_PASS = 1 THEN
        call p_logSp(in_sp_name, 'SpStart', in_event_desc, 'info', 0, inout_sp_exec_no);
    END IF;
END;


DROP procedure IF EXISTS `logSpEnd`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `logSpEnd`(
    in    in_sp_name        varchar(100),
    in    in_event_desc     varchar(500),
    inout inout_sp_exec_no  bigint
    )
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 记录Sp成功运行结束的日志
     *
     * in_sp_name           输入        varchar(100)    必输，需要记录日志的当前运行SP名称
     * in_event_desc        输入        varchar(500)    可选，事件详情，可自定义输入500字以内的文本
     * inout_sp_exec_no     输入输出     bigint          SP本次运行的唯一运行编号
     * ========================================== */
    call p_logSp(in_sp_name, 'SpEnd', in_event_desc, 'info', 1, inout_sp_exec_no);
END;


DROP procedure IF EXISTS `logSpErrAndEnd`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `logSpErrAndEnd`(
    in    in_sp_name        varchar(100),
    in    in_event_desc     varchar(500),
    inout inout_sp_exec_no        bigint
    )
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 记录Sp异常等运行失败的日志,并结束SP
     *
     * in_sp_name           输入        varchar(100)    必输，需要记录日志的当前运行SP名称
     * in_event_desc        输入        varchar(500)    可选，事件详情，可自定义输入500字以内的文本
     * sp_exec_no           输入输出     bigint          SP本次运行的唯一运行编号
     * ========================================== */
    call p_logSp(in_sp_name, 'sperr', in_event_desc, 'err', 1, inout_sp_exec_no);
END;



DROP procedure IF EXISTS `logSpErrAndContinue`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `logSpErrAndContinue`(
    in    in_sp_name        varchar(100),
    in    in_event_desc     varchar(500),
    inout inout_sp_exec_no  bigint
    )
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 记录Sp异常等运行失败的日志, SP继续运行
     *
     * in_sp_name           输入        varchar(100)    必输，需要记录日志的当前运行SP名称
     * in_event_desc        输入        varchar(500)    可选，事件详情，可自定义输入500字以内的文本
     * inout_sp_exec_no     输入输出     bigint          SP本次运行的唯一运行编号
     * ========================================== */
    call p_logSp(in_sp_name, 'sperr', in_event_desc, 'err', 0, inout_sp_exec_no);
END;



DROP procedure IF EXISTS `logSpInfo`;
CREATE DEFINER=`nicholas.qu`@`%` PROCEDURE `logSpInfo`(
    in    in_sp_name        varchar(100),
    in    in_event_desc     varchar(500),
    inout inout_sp_exec_no  bigint
    )
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 记录Sp内部详细步骤的日志
     *
     * in_sp_name           输入        varchar(100)    必输，需要记录日志的当前运行SP名称
     * in_event_desc        输入        varchar(500)    可选，事件详情，可自定义输入500字以内的文本
     * inout_sp_exec_no     输入输出     bigint          SP本次运行的唯一运行编号
     * ========================================== */
    call p_logSp(in_sp_name, 'spinfo', in_event_desc, 'info', 0, inout_sp_exec_no);
END;


DROP FUNCTION IF EXISTS `f_ops_checkSpConditions`;
CREATE DEFINER=`nicholas.qu`@`%` FUNCTION `f_ops_checkSpConditions`(
    in_sp_name                  varchar(100),
    from_time                   datetime,
    to_time                     datetime,
    cond_sp_running             tinyint,
    cond_sp_end_exist           tinyint,
    cond_sp_end_no_err          tinyint,
    cond_sp_end_no_warn         tinyint
    )
RETURNS tinyint
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 检查SP的阻塞情况，用于判断依赖的SP是否成功运行等
     *
     * in_sp_name           varchar(100)    必输，需要校验的SP名称
     * from_time            datetime        必输，判断时间窗口的开始时间
     * to_time              datetime        必输，判断时间窗口的结束时间
     * cond_sp_running      tinyint         必输，1-时间段内此SP正在运行中 0-不做判断
     * cond_sp_end_exist    tinyint         必输，1-时间段内必须存在一条此SP运行结束的记录 0-不做判断
     * cond_sp_end_no_err   tinyint         必输，1-若时间段内存在此SP运行结束的记录，则运行过程不能有ERR 0-不做判断 
     * cond_sp_end_no_warn  tinyint         必输，1-若时间段内存在此SP运行结束的记录，则运行过程不能有WARN 0-不做判断 
     * 
     * 返回值：1-满足所有条件 0-不满足条件
     * ========================================== */
    
    /*SP最后一次运行的执行编号*/
    DECLARE V_SP_LAST_EXEC_NO       bigint; 
    /*SP最后一次运行的最终状态, int小心处理，若查不到记录，该值为0，与运行中状态0无法分别*/
    DECLARE V_SP_LAST_EXEC_STATE    tinyint;
    DECLARE V_SP_LAST_CNT           tinyint;

    DECLARE `V_SP_END_ERR_CNT`      int;
    DECLARE `V_SP_END_WARN_CNT`     int;
    
    select IFNULL(cond_sp_running, -1) into cond_sp_running;
    select IFNULL(cond_sp_end_exist, -1) into cond_sp_end_exist;
    select IFNULL(cond_sp_end_no_err, -1) into cond_sp_end_no_err;
    select IFNULL(cond_sp_end_no_warn, -1) into cond_sp_end_no_warn;

    /*不查询检查类日志*/
    select sp_exec_no, running_state
    into V_SP_LAST_EXEC_NO, V_SP_LAST_EXEC_STATE
    from ops_sp_logs 
    where sp_name = lower(in_sp_name)
    and running_state >=0 
    and log_time >= from_time
    and log_time <= to_time
    order by id desc
    limit 1;
    
    select row_count() into V_SP_LAST_CNT;

    select IFNULL(V_SP_LAST_EXEC_NO, -1) into V_SP_LAST_EXEC_NO;
    select IFNULL(V_SP_LAST_EXEC_STATE, -1) into V_SP_LAST_EXEC_STATE;
    
    IF cond_sp_running = 1 THEN
        /*条件是存在运行中的SP，却不存在直接返回*/
        IF V_SP_LAST_CNT=0 THEN
            return 0;
        END IF;
        IF V_SP_LAST_CNT>0 AND V_SP_LAST_EXEC_STATE <> 0 THEN
            return 0;
        END IF;
    END IF;
    
    IF cond_sp_end_exist = 1 AND V_SP_LAST_EXEC_STATE <> 1 THEN
        /*条件是时间段内必须存在一条此SP运行结束的记录, 却不存在*/
        return 0;
    END IF;


    select 
        sum(case when log_level = 'err' then 1 else 0 end),
        sum(case when log_level = 'warn' then 1 else 0 end)
    into `V_SP_END_ERR_CNT`, `V_SP_END_WARN_CNT`
    from ops_sp_logs
    where sp_exec_no = V_SP_LAST_EXEC_NO;

    IF cond_sp_end_no_err = 1 AND `V_SP_END_ERR_CNT` > 0 THEN
        /*若时间段内存在此SP运行结束的记录，则运行过程不能有ERR*/
        return 0;
    END IF;
    IF cond_sp_end_no_warn = 1 AND `V_SP_END_WARN_CNT` > 0 THEN
        /*若时间段内存在此SP运行结束的记录，则运行过程不能有WARN*/
        return 0;
    END IF;

    /*全部满足条件。*/
    return 1; 
END;


DROP FUNCTION IF EXISTS `hasSpSelfRunMeanwhile`;
CREATE DEFINER=`nicholas.qu`@`%` FUNCTION `hasSpSelfRunMeanwhile`(
    `self_sp_name`     varchar(100),
    `event_interval`   bigint
    )
RETURNS tinyint
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 检查是否存在自身仍旧在运行中的SP, 导致自身重复交叉运行，
     * 时间窗口从 now()-event_interval 到 now()。
     *
     * self_sp_name         varchar(100)    必输，自身SP名称
     * event_interval       bigint          必输，运行SP的event的时间间隔,单位分钟
     *
     * 返回参数 1=存在自身还在运行的SP 0-不存在 -1=传入参数错误
     * ========================================== */
    DECLARE V_MEET_CONDITIONS tinyint; 

    /*传入空的SP名称*/
    if self_sp_name is null OR length(trim(self_sp_name)) = 0 then
        return -1;
    end if;

    /*默认值10分钟间隔，自身校验最多T+1*/
    IF `event_interval` is null OR `event_interval` = 0 THEN
        select 10 into `event_interval`;
    ELSEIF `event_interval` > 24 * 60 THEN
        select 24 * 60 into `event_interval`;
    END IF;

    select f_ops_checkSpConditions(
                self_sp_name, 
                from_unixtime(UNIX_TIMESTAMP(now()) - `event_interval`*60),
                now(),
                1,0,0,0)
    into V_MEET_CONDITIONS;

    return V_MEET_CONDITIONS;
END;


DROP FUNCTION IF EXISTS `isSpEndSucc`;
CREATE DEFINER=`nicholas.qu`@`%` FUNCTION `isSpEndSucc`(
    check_sp_name   varchar(100),
    from_time       datetime,
    to_time         datetime
    )
RETURNS tinyint
BEGIN
    /* ==========================================
     * NicholasQu|20190822: 检查依赖的SP
     * 1. 时间段内的最后一次运行必须是已结束;
     * 2. 时间段内的最后一次运行不存在ERR异常;
     *
     * check_sp_name        varchar(100)    必输，依赖的SP名称
     * from_time            datetime        必输，判断时间窗口的开始时间
     * to_time              datetime        必输，判断时间窗口的结束时间
     * 返回参数 1=依赖的SP运行成功 0-不成功 -1=传入参数有误
     * ========================================== */
    DECLARE V_MEET_CONDITIONS tinyint; 
    DECLARE V_SP_EXEC_NO      bigint; 

    /*传入空的SP名称*/
    if check_sp_name is null OR length(trim(check_sp_name)) = 0 then
        return -1;
    end if;

    select f_ops_checkSpConditions(
                check_sp_name, 
                from_time,
                to_time,
                0,1,1,0)
    into V_MEET_CONDITIONS;     

    return V_MEET_CONDITIONS;
END;



/**********************************************
 *  使用示例
 **********************************************/
call logSpStart('sp1','testing sp1',100,@sp_exec_no);
call logSpStartAndCheck('sp1','testing sp1',100,'sp2', date_add(now(), interval -1 minute), now(), @sp_exec_no);
call logSpEnd('sp1','end sp1', @sp_exec_no);