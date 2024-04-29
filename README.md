实验报告附有仿真文件“inverted_pendulum”,运行该文件需要将动画绘制代码“pendan.m”与其放在同一文件夹下，同时，需要为Fuzzy Logic Controller模块导入模糊控制器设计文件“fuzzy_control.fis”，具体导入方法不再赘述。




引入de后，控制规则如下：
e\ de	NB	NS	ZO	PS	PB
NB	NB	NB	NB	NS	NB
NS	NB	NB	NS	PB	PS
ZO	NB	NB	ZO	PB	PB
PS	PS	NB	PS	PB	PB
PB	PB	PS	PB	PB	PB

