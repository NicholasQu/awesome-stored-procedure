## SP启动和先决条件检查
用于记录SP启动时间和状态，并检查可以继续运行的条件是否满足：
1. 自身的运行频度较高，之前自身是否还未运行完成。该情况调用logSpStart即可；
2. 依赖其他的SP运行完成，自身方能启动。该情况需调用logSpStartAndCheck；

## SP调试信息打印
用于打印Info级别的调试日志, 调用logSpInfo;

## SP结束日志打印 logSpEnd
用于表示该SP已运行完成。注意这里只标识SP的完成，并不一定成功，整个SP中间过程可能发生了异常，但是继续运行完毕了。

## SP异常处理
对异常进行处理。有两种方式：
1. 若该异常无关痛痒，可以继续后续逻辑的话，使用logSpErrAndContinue;
2. 若该异常直接可以导致SP终止，调用logSpErrAndEnd;

## 标准SP写法
参照 p_sp_demo.MYSQL.SP.sql

