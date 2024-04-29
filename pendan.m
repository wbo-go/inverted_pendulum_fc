function pendan(block,varargin)
%PENDAN S-function for making pendulum animation.
%
%   See also: PENDDEMO.

%   Copyright 1990-2023 The MathWorks, Inc.

% Plots every major integration step, but has no states of its own
    if nargin == 1
        setup(block);
    else
        switch varargin{end}
            %删除块
            case 'DeleteBlock',
                LocalDeleteBlock
            %删除图形
            case 'DeleteFigure',
                LocalDeleteFigure
            %滑块调整
            case 'Slider',
                LocalSlider
            %关闭窗口
            case 'Close',
                LocalClose
            %回放动作
            case 'Playback',
                LocalPlayback
        end
    end
end

function setup(block) %定义S-Function的主要属性
    % Register parameters 注册参数
    block.NumDialogPrms = 1; % RefBlock
    
    % 注册端口数 
    block.NumInputPorts = 1;
    block.NumOutputPorts = 0;

    % 覆写输入输出端口属性
    block.InputPort(1).DatatypeID = 0;
    block.InputPort(1).Dimensions = 3;
    block.InputPort(1).DirectFeedthrough = true;

    %
    % initialize the array of sample times, for the pendulum example,
    % the animation is updated every 0.1 seconds
    block.SampleTimes = [0.1 0];

    %
    % create the figure, if necessary
    %
    LocalPendInit(block.DialogPrm(1).Data); % RefBlock
    
    %
    % specify that the simState for this s-function is same as the default
    %
    block.SimStateCompliance = 'DefaultSimState';

    block.RegBlockMethod('Update', @mdlUpdate);
    block.RegBlockMethod('Terminate', @mdlTerminate);
end


%
%=============================================================================
% mdlUpdate
% Update the pendulum animation.
%=============================================================================
%
function mdlUpdate(block)
    t = block.CurrentTime;
    u = block.InputPort(1).Data;

    fig = get_param(gcbh,'UserData');
    if ishghandle(fig, 'figure'),
      if strcmp(get(fig,'Visible'),'on'),
        ud = get(fig,'UserData');
        LocalPendSets(t,ud,u);
      end
    end;
end

%
%=============================================================================
% mdlTerminate
% Re-enable playback buttong for the pendulum animation.
%=============================================================================
%
function mdlTerminate(block) 

    fig = get_param(gcbh,'UserData');
    if ishghandle(fig, 'figure')
        pushButtonPlayback = findobj(fig,'Tag','penddemoPushButton');
        set(pushButtonPlayback,'Enable','on');
    end
end

%
%=============================================================================
% LocalDeleteBlock
% The animation block is being deleted, delete the associated figure.
%=============================================================================
%
function LocalDeleteBlock

    fig = get_param(gcbh,'UserData');
    if ishghandle(fig, 'figure')
      delete(fig);
      set_param(gcbh,'UserData',-1)
    end
end

%
%=============================================================================
% LocalDeleteFigure
% The animation figure is being deleted, set the S-function UserData to -1.
%=============================================================================
%
function LocalDeleteFigure

    ud = get(gcbf,'UserData');
    set_param(ud.Block,'UserData',-1);
end

%
%=============================================================================
% LocalSlider
% The callback function for the animation window slider uicontrol.  Change
% the reference block's value.
%=============================================================================
%
function LocalSlider

    ud = get(gcbf,'UserData');
    set_param(ud.RefBlock,'Value',num2str(get(gcbo,'Value')));
end

%
%=============================================================================
% LocalClose
% The callback function for the animation window close button.  Delete
% the animation figure window.
%=============================================================================
%
function LocalClose

    delete(gcbf)
end

%
%=============================================================================
% LocalPlayback
% The callback function for the animation window playback button.  Playback
% the animation.
%=============================================================================
%
function LocalPlayback

    %
    % first find the animation data in the base workspace, issue an error
    % if the information isn't there
    %
    t = evalin('base','t','[]');
    y = evalin('base','y','[]');
    
    if isempty(t) || isempty(y),
      errordlg(...
        ['You must first run the simulation before '...
         'playing back the animation.'],...
        'Animation Playback Error');
    end
    
    %
    % playback the animation, note that the playback is wrapped in a try-catch
    % because is it is possible for the figure and it's children to be deleted
    % during the drawnow in LocalPendSets
    %
    try
      ud = get(gcbf,'UserData');
      for i=1:length(t),
        LocalPendSets(t(i),ud,y(i,:));
      end
    catch %#ok<CTCH>
        % do nothing
    end
end

%
%=============================================================================
% LocalPendSets
% Local function to set the position of the graphics objects in the
% inverted pendulum animation window.
%=============================================================================
%
function LocalPendSets(time,ud,u)

    XDelta   = 2;
    PDelta   = 0.2;
    XPendTop = u(2) + 10*sin(u(3));
    YPendTop = 10*cos(u(3));
    PDcosT   = PDelta*cos(u(3));
    PDsinT   = -PDelta*sin(u(3));
    set(ud.Cart,...
      'XData',ones(2,1)*[u(2)-XDelta u(2)+XDelta]);
    set(ud.Pend,...
      'XData',[XPendTop-PDcosT XPendTop+PDcosT; u(2)-PDcosT u(2)+PDcosT], ...
      'YData',[YPendTop-PDsinT YPendTop+PDsinT; -PDsinT PDsinT]);
    set(ud.TimeField,...
      'String',num2str(time));
    set(ud.RefMark,...
      'XData',u(1)+[-XDelta 0 XDelta]);
    
    % Force plot to be drawn
    pause(0)
    drawnow
end

%
%=============================================================================
% LocalPendInit
% Local function to initialize the pendulum animation.  If the animation
% window already exists, it is brought to the front.  Otherwise, a new
% figure window is created.
%=============================================================================
%
function LocalPendInit(RefBlock)


    % The name of the reference is derived from the name of the
    % subsystem block that owns the pendulum animation S-function block.
    % This subsystem is the current system and is assumed to be the same
    % layer at which the reference block resides.

    sys = get_param(gcs,'Parent'); %获取当前simulink系统的（gcs代表当前系统）的父系统的路径，通常是包含S-function的子系统
    
    TimeClock = 0;%记录动画当前时间
    RefSignal = str2double(get_param([sys '/' RefBlock],'Value'));%从simulink模型中获取名为"RefBlock"的参考块的参数值并将其从字符串转换为双精度数值类型存入'RefSingal'
    XCart     = 0; %小车位置
    Theta     = 0; %摆杆角度
    
    XDelta    = 2;   % 定义了小车宽度的一半
    PDelta    = 0.2; % 摆杆宽度的一半
    XPendTop  = XCart + 10*sin(Theta); % Will be zero 摆杆顶部XY坐标
    YPendTop  = 10*cos(Theta);         % Will be 10
    PDcosT    = PDelta*cos(Theta);     % Will be 0.2
    PDsinT    = -PDelta*sin(Theta);    % Will be zero
    
    %
    % The animation figure handle is stored in the pendulum block's UserData.
    % If it exists, initialize the reference mark, time, cart, and pendulum
    % positions/strings/etc.
    %
    Fig = get_param(gcbh,'UserData'); % 提取动画图形的句柄
    if ishghandle(Fig ,'figure'),
      FigUD = get(Fig,'UserData');    % 从图形对象中获取UserData属性，包含动画控件的句柄信息
      set(FigUD.RefMark,... %参考位置
          'XData',RefSignal+[-XDelta 0 XDelta]);
      set(FigUD.TimeField,...%显示动画时间
          'String',num2str(TimeClock));
      set(FigUD.Cart,...%定义并显示小车位置
          'XData',ones(2,1)*[XCart-XDelta XCart+XDelta]);
      set(FigUD.Pend,...%定义并显示摆杆位置
          'XData',[XPendTop-PDcosT XPendTop+PDcosT; XCart-PDcosT XCart+PDcosT],...
          'YData',[YPendTop-PDsinT YPendTop+PDsinT; -PDsinT PDsinT]);
      
      % disable playback button during simulation禁用Playback
      pushButtonPlayback = findobj(Fig,'Tag','penddemoPushButton');
      set(pushButtonPlayback,'Enable','off');
            
      %
      % bring it to the front
      %
      figure(Fig);
      return
    end
    
    %
    % the animation figure doesn't exist, create a new one and store its
    % handle in the animation block's UserData
    %
    FigureName = 'Pendulum Animation';
    Fig = figure(...
      'Units',           'pixel',...
      'Position',        [100 100 500 300],...
      'Name',            FigureName,...
      'NumberTitle',     'off',...
      'IntegerHandle',   'off',...
      'HandleVisibility','callback',...
      'Resize',          'off',...
      'DeleteFcn',       'pendan([],[],[],''DeleteFigure'')',...
      'CloseRequestFcn', 'pendan([],[],[],''Close'');');
    AxesH = axes(...
      'Parent',  Fig,...
      'Units',   'pixel',...
      'Position',[50 50 400 200],...
      'CLim',    [1 64], ...
      'Xlim',    [-12 12],...
      'Ylim',    [-2 10],...
      'Visible', 'off');
    %创建小车平面对象
    Cart = surface(...
      'Parent',   AxesH,...
      'XData',    ones(2,1)*[XCart-XDelta XCart+XDelta],...
      'YData',    [0 0; -2 -2],...
      'ZData',    zeros(2),...
      'CData',    11*ones(2));
    Pend = surface(...
      'Parent',   AxesH,...
      'XData',    [XPendTop-PDcosT XPendTop+PDcosT; XCart-PDcosT XCart+PDcosT],...
      'YData',    [YPendTop-PDsinT YPendTop+PDsinT; -PDsinT PDsinT],...
      'ZData',    zeros(2),...
      'CData',    11*ones(2));
    RefMark = patch(...
      'Parent',   AxesH,...
      'XData',    RefSignal+[-XDelta 0 XDelta],...
      'YData',    [-2 0 -2],...
      'CData',    22,...
      'FaceColor','flat');
    uicontrol(...
      'Parent',  Fig,...
      'Style',   'text',...
      'Units',   'pixel',...
      'Position',[0 0 500 50]);
    uicontrol(...
      'Parent',             Fig,...
      'Style',              'text',...
      'Units',              'pixel',...
      'Position',           [150 0 100 25], ...
      'HorizontalAlignment','right',...
      'String',             'Time: ');
    TimeField = uicontrol(...
      'Parent',             Fig,...
      'Style',              'text',...
      'Units',              'pixel', ...
      'Position',           [250 0 100 25],...
      'HorizontalAlignment','left',...
      'String',             num2str(TimeClock));
    %滑动条控件，设置回调函数以响应滑动事件
    SlideControl = uicontrol(...
      'Parent',   Fig,...
      'Style',    'slider',...
      'Units',    'pixel', ...
      'Position', [76 25 348 22],...
      'Min',      -2*pi,...
      'Max',      0,...
      'Value',    RefSignal,...
      'Callback', 'pendan([],[],[],''Slider'');');
    uicontrol(...
      'Parent',  Fig,...
      'Style',   'pushbutton',...
      'Position',[430 15 70 20],...
      'String',  'Close', ...
      'Callback','pendan([],[],[],''Close'');');
    uicontrol(...
      'Parent',  Fig,...
      'Style',   'pushbutton',...
      'Position',[5 15 70 20],...
      'String',  'Playback', ...
      'Callback','pendan([],[],[],''Playback'');',...
      'Interruptible','off',...
      'BusyAction','cancel', ...
      'Tag','penddemoPushButton',...
      'Enable','off');
    
    %
    % all the HG objects are created, store them into the Figure's UserData
    %
    %将所有对象存储到结构体中
    FigUD.Cart         = Cart;
    FigUD.Pend         = Pend;
    FigUD.TimeField    = TimeField;
    FigUD.SlideControl = SlideControl;
    FigUD.RefMark      = RefMark;
    FigUD.Block        = get_param(gcbh,'Handle');
    FigUD.RefBlock     = get_param([sys '/' RefBlock],'Handle');
    set(Fig,'UserData',FigUD);
    
    %强制matlab立即绘制所有挂起的图形操作，确保动画窗口立即更新
    drawnow
    
    %
    % store the figure handle in the animation block's UserData
    %
    set_param(gcbh,'UserData',Fig);
end
