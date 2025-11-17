% =========================================================================
% InstructionAndPractice.m
% =========================================================================
% 触觉-视觉同步感知实验：指导语和练习部分
%
% 功能：
% 1. 显示3页指导语
% 2. 运行3个练习trials（不记录数据）
% 3. 完成后通知实验者
%
% 版本：V1.0
% 日期：2025-11-17
% =========================================================================

function InstructionAndPractice()

    %% ===== 清理环境 =====
    close all;
    clearvars;
    sca; % Screen Close All

    % 添加Psychtoolbox路径（如果需要）
    try
        PsychtoolboxVersion;
    catch
        error('Psychtoolbox未正确安装或未添加到路径中');
    end

    %% ===== 获取被试ID =====
    participantID = input('请输入被试ID (e.g., P001): ', 's');
    if isempty(participantID)
        participantID = 'P999';
        fprintf('未输入ID，使用默认ID: %s\n', participantID);
    end

    %% ===== 实验参数 =====
    % 音频参数
    fs = 48000;                    % 采样率
    audioDeviceIndex = 5;          % MOTU音频接口
    nAudioChannels = 2;            % 音频立体声通道
    audioAtten = 0.5;              % 音频衰减
    hapticBoost = 1.0;             % 触觉增益

    % 触觉通道
    hapticChans = [4 5 8 9 10];    % MOTU的5个触觉输出通道
    nOutputChannels = max([nAudioChannels, hapticChans]); % 总输出通道数

    % 视频参数
    assumeFPS = 25;                % 视频帧率

    % 练习trials设置
    practiceClips = [1, 2, 3];     % 使用的视频片段
    practiceOffsets = [-200, 0, 200]; % 时间偏移量（ms）

    % 文字大小
    instructionFontSize = 56;
    questionFontSize = 72;
    answerFontSize = 56;

    %% ===== 检查文件 =====
    fprintf('\n===== 检查实验文件 =====\n');

    % 检查视频文件
    for i = 1:3
        videoFile = sprintf('video_%d.mp4', i);
        if ~exist(videoFile, 'file')
            error('找不到视频文件: %s', videoFile);
        end
        fprintf('✓ 找到: %s\n', videoFile);
    end

    % 检查音频文件
    for i = 1:3
        audioFile = sprintf('audio_%d.wav', i);
        if ~exist(audioFile, 'file')
            error('找不到音频文件: %s', audioFile);
        end
        fprintf('✓ 找到: %s\n', audioFile);
    end

    % 检查触觉文件
    for i = 1:3
        hapticFile = sprintf('haptic_%d.wav', i);
        if ~exist(hapticFile, 'file')
            error('找不到触觉文件: %s', hapticFile);
        end
        fprintf('✓ 找到: %s\n', hapticFile);
    end

    fprintf('所有文件检查完成！\n\n');

    %% ===== 初始化Psychtoolbox =====
    fprintf('===== 初始化Psychtoolbox =====\n');

    % 设置Psychtoolbox
    PsychDefaultSetup(2);
    Screen('Preference', 'SkipSyncTests', 1); % 跳过同步测试（仅用于测试）
    Screen('Preference', 'VisualDebugLevel', 1);
    Screen('Preference', 'SuppressAllWarnings', 1);

    % 获取屏幕
    screens = Screen('Screens');
    screenNumber = max(screens);

    % 打开窗口
    [win, winRect] = Screen('OpenWindow', screenNumber, [128 128 128]);
    [screenXpixels, screenYpixels] = Screen('WindowSize', win);
    [xCenter, yCenter] = RectCenter(winRect);

    fprintf('✓ 屏幕分辨率: %d × %d\n', screenXpixels, screenYpixels);

    % 设置文字
    Screen('TextSize', win, instructionFontSize);
    Screen('TextFont', win, 'Arial');

    % 隐藏鼠标
    HideCursor;

    %% ===== 初始化音频 =====
    fprintf('===== 初始化音频 =====\n');

    % 初始化音频驱动
    InitializePsychSound(1);

    % 打开音频设备
    pahandle = PsychPortAudio('Open', audioDeviceIndex, 1, 1, fs, nOutputChannels);

    % 获取设备信息
    audioInfo = PsychPortAudio('GetStatus', pahandle);
    fprintf('✓ 音频设备: %d\n', audioDeviceIndex);
    fprintf('✓ 采样率: %d Hz\n', fs);
    fprintf('✓ 输出通道数: %d\n', nOutputChannels);

    %% ===== 预加载视频 =====
    fprintf('\n===== 预加载视频 =====\n');
    fprintf('正在加载视频，请稍候...\n');

    videoTextures = cell(3, 1);

    for clipIdx = 1:3
        videoFile = sprintf('video_%d.mp4', clipIdx);
        fprintf('加载视频 %d/%d: %s\n', clipIdx, 3, videoFile);

        % 打开视频
        [movie, ~, ~, imgw, imgh] = Screen('OpenMovie', win, videoFile);

        % 计算缩放比例（全屏）
        scaleX = screenXpixels / imgw;
        scaleY = screenYpixels / imgh;
        scale = max(scaleX, scaleY);
        dstRect = CenterRect([0 0 imgw*scale imgh*scale], winRect);

        % 预加载所有帧
        textures = [];
        frameIdx = 0;

        while true
            tex = Screen('GetMovieImage', win, movie, 1);
            if tex <= 0
                break;
            end
            frameIdx = frameIdx + 1;
            textures(frameIdx) = tex;
        end

        % 关闭视频
        Screen('CloseMovie', movie);

        % 保存
        videoTextures{clipIdx}.textures = textures;
        videoTextures{clipIdx}.dstRect = dstRect;
        videoTextures{clipIdx}.nFrames = length(textures);

        fprintf('  ✓ 加载了 %d 帧\n', length(textures));
    end

    fprintf('所有视频加载完成！\n\n');

    %% ===== 显示指导语 =====
    fprintf('===== 显示指导语 =====\n');

    % ===== 第1页：欢迎和实验简介 =====
    instructionText1 = {
        '欢迎参加本次实验！'
        ''
        '在本实验中，您将观看一系列短视频片段（每个10秒）。'
        ''
        '同时，您会通过触觉装置感受到振动反馈。'
        ''
        '您的任务是：'
        '  • 仔细观看视频'
        '  • 专注感受触觉反馈'
        '  • 回答几个简单的问题'
        ''
        ''
        '按 SPACE 键继续 →'
    };

    ShowInstructionPage(win, xCenter, yCenter, instructionText1, instructionFontSize);

    % ===== 第2页：问题详细说明 =====
    instructionText2 = {
        '每个视频播放后，您需要回答3个问题：'
        ''
        '问题1: 您能感受到触觉反馈吗？'
        '        1 = 能    2 = 不能'
        ''
        '问题2: 触觉反馈与视频的同步程度如何？'
        '        1 = 完全不同步    7 = 完全同步'
        ''
        '问题3: 触觉反馈的真实感如何？'
        '        1 = 完全不真实    7 = 非常真实'
        ''
        ''
        '按数字键选择答案，按SPACE确认'
        ''
        '按 SPACE 键继续 →'
    };

    ShowInstructionPage(win, xCenter, yCenter, instructionText2, instructionFontSize);

    % ===== 第3页：重要提示 =====
    instructionText3 = {
        '重要提示：'
        ''
        '  • 请保持注意力集中'
        '  • 凭第一感觉作答，不要过度思考'
        '  • 确认前可以修改答案'
        '  • 任何时候按ESC键可以退出'
        ''
        '正式实验开始前，您将完成3个练习trials'
        '以熟悉实验流程。'
        ''
        '练习数据不会被记录。'
        ''
        ''
        '准备好后，按 SPACE 键开始练习 →'
    };

    ShowInstructionPage(win, xCenter, yCenter, instructionText3, instructionFontSize);

    %% ===== 练习Trials =====
    fprintf('\n===== 开始练习 =====\n');

    for practiceIdx = 1:3
        clipIdx = practiceClips(practiceIdx);
        offset_ms = practiceOffsets(practiceIdx);

        fprintf('\n--- 练习 %d/3 ---\n', practiceIdx);
        fprintf('视频: %d, Offset: %d ms\n', clipIdx, offset_ms);

        % 加载音频和触觉
        audioFile = sprintf('audio_%d.wav', clipIdx);
        hapticFile = sprintf('haptic_%d.wav', clipIdx);

        [A, ~] = audioread(audioFile);
        [Hm, ~] = audioread(hapticFile);

        % 确保音频是立体声
        if size(A, 2) == 1
            A = [A, A];
        end

        % 应用衰减
        A = A * audioAtten;
        Hm = Hm * hapticBoost;

        % 应用offset到触觉信号
        shiftSamples = round(offset_ms * 1e-3 * fs);

        if shiftSamples > 0
            % 正offset：延迟触觉
            Hm = [zeros(shiftSamples, 1); Hm];
        elseif shiftSamples < 0
            % 负offset：提前触觉
            absShift = abs(shiftSamples);
            if absShift < length(Hm)
                Hm = Hm(1 + absShift : end);
            else
                Hm = zeros(size(Hm));
            end
        end

        % 匹配长度
        maxLen = max(size(A, 1), length(Hm));
        if size(A, 1) < maxLen
            A = [A; zeros(maxLen - size(A, 1), 2)];
        end
        if length(Hm) < maxLen
            Hm = [Hm; zeros(maxLen - length(Hm), 1)];
        end

        % 构建多通道音频矩阵
        multiChanAudio = zeros(maxLen, nOutputChannels);
        multiChanAudio(:, 1:2) = A;
        for hc = 1:length(hapticChans)
            multiChanAudio(:, hapticChans(hc)) = Hm;
        end

        % 填充音频缓冲
        PsychPortAudio('FillBuffer', pahandle, multiChanAudio');

        % 播放视频和音频
        videoData = videoTextures{clipIdx};
        frameDuration = 1 / assumeFPS;

        fprintf('开始播放...\n');

        % 显示第一帧
        Screen('DrawTexture', win, videoData.textures(1), [], videoData.dstRect);
        firstFlip = Screen('Flip', win);

        % 启动音频
        audStart = PsychPortAudio('Start', pahandle, 1, firstFlip, 1);

        % 播放剩余帧
        for frameIdx = 2:videoData.nFrames
            Screen('DrawTexture', win, videoData.textures(frameIdx), [], videoData.dstRect);
            Screen('Flip', win, firstFlip + (frameIdx - 1) * frameDuration);
        end

        % 等待音频播放完成
        PsychPortAudio('Stop', pahandle, 1);

        % 清空屏幕
        Screen('Flip', win);
        WaitSecs(0.5);

        % 回答问题
        fprintf('回答问题...\n');

        % 问题1
        q1_response = AskQuestion(win, xCenter, yCenter, ...
            'Can you feel the haptic feedback?', ...
            {'1 = Yes', '2 = No'}, ...
            [1, 2], questionFontSize, answerFontSize);

        % 问题2
        q2_response = AskQuestion(win, xCenter, yCenter, ...
            'How synchronized did the haptic feel with the video?', ...
            {'1 = Completely out of sync', '7 = Perfectly in sync'}, ...
            1:7, questionFontSize, answerFontSize);

        % 问题3
        q3_response = AskQuestion(win, xCenter, yCenter, ...
            'How realistic was the haptic feedback?', ...
            {'1 = Not realistic at all', '7 = Very realistic'}, ...
            1:7, questionFontSize, answerFontSize);

        fprintf('  Q1: %d, Q2: %d, Q3: %d\n', q1_response, q2_response, q3_response);
        fprintf('练习 %d 完成！\n', practiceIdx);
    end

    %% ===== 练习完成 =====
    fprintf('\n===== 练习完成 =====\n');

    completionText = {
        '练习部分已完成！'
        ''
        '如果您对实验流程还有任何疑问，'
        '请现在向实验者提出。'
        ''
        '如果没有问题，请通知实验者。'
        ''
        '实验者将为您启动正式实验。'
        ''
        ''
        '按 SPACE 键退出'
    };

    ShowInstructionPage(win, xCenter, yCenter, completionText, instructionFontSize);

    %% ===== 清理 =====
    fprintf('\n===== 清理资源 =====\n');

    % 关闭音频
    PsychPortAudio('Close', pahandle);

    % 关闭所有纹理
    for clipIdx = 1:3
        for tex = videoTextures{clipIdx}.textures
            Screen('Close', tex);
        end
    end

    % 关闭窗口
    sca;
    ShowCursor;

    fprintf('指导语和练习脚本已完成！\n');
    fprintf('被试ID: %s\n', participantID);

end

%% ===== 辅助函数：显示指导语页面 =====
function ShowInstructionPage(win, xCenter, yCenter, textLines, fontSize)
    % 设置文字
    Screen('TextSize', win, fontSize);

    % 计算总高度
    lineHeight = fontSize * 1.3;
    totalHeight = length(textLines) * lineHeight;
    startY = yCenter - totalHeight / 2;

    % 绘制文字
    Screen('FillRect', win, [128 128 128]);

    for i = 1:length(textLines)
        DrawFormattedText(win, textLines{i}, 'center', startY + (i-1) * lineHeight, [255 255 255]);
    end

    Screen('Flip', win);

    % 等待按键
    WaitForSpace();
end

%% ===== 辅助函数：询问问题 =====
function response = AskQuestion(win, xCenter, yCenter, questionText, scaleLabels, validKeys, questionFontSize, answerFontSize)

    selectedKey = [];
    confirmed = false;

    while ~confirmed
        % 绘制问题
        Screen('FillRect', win, [128 128 128]);

        % 问题文本
        Screen('TextSize', win, questionFontSize);
        DrawFormattedText(win, questionText, 'center', yCenter - 200, [255 255 255]);

        % 量表标签
        Screen('TextSize', win, answerFontSize);
        yOffset = yCenter - 50;

        for i = 1:length(scaleLabels)
            DrawFormattedText(win, scaleLabels{i}, 'center', yOffset + (i-1) * 80, [255 255 255]);
        end

        % 显示选择
        if ~isempty(selectedKey)
            selectionText = sprintf('您的选择: %d', selectedKey);
            if confirmed
                DrawFormattedText(win, [selectionText ' ✓'], 'center', yCenter + 250, [0 255 0]);
            else
                DrawFormattedText(win, selectionText, 'center', yCenter + 250, [255 255 0]);
            end
        end

        % 提示
        if isempty(selectedKey)
            DrawFormattedText(win, 'Please select a number', 'center', yCenter + 350, [200 200 200]);
        else
            DrawFormattedText(win, 'Press SPACE to confirm or select another number', 'center', yCenter + 350, [200 200 200]);
        end

        Screen('Flip', win);

        % 等待按键
        [~, keyCode] = KbStrokeWait;

        % 检查ESC
        if keyCode(KbName('ESCAPE'))
            error('实验被用户中止');
        end

        % 检查数字键
        for key = validKeys
            if keyCode(KbName(num2str(key)))
                selectedKey = key;
                break;
            end
        end

        % 检查SPACE（确认）
        if keyCode(KbName('space')) && ~isempty(selectedKey)
            confirmed = true;
        end
    end

    response = selectedKey;
end

%% ===== 辅助函数：等待SPACE键 =====
function WaitForSpace()
    while true
        [~, keyCode] = KbStrokeWait;

        % 检查ESC
        if keyCode(KbName('ESCAPE'))
            error('实验被用户中止');
        end

        % 检查SPACE
        if keyCode(KbName('space'))
            break;
        end
    end
end
