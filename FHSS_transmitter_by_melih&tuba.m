function FHSS_transmitter()
    % Create the GUI figure
    fig = figure('Name', 'FHSS Transmitter', 'NumberTitle', 'off', 'Position', [100, 100, 600, 400]);

    % Create input fields for text message, sampling rate, hop period, and deltaF
    uicontrol('Style', 'text', 'Position', [20, 340, 100, 20], 'String', 'Text Message:');
    textInput = uicontrol('Style', 'edit', 'Position', [130, 340, 200, 20]);

    uicontrol('Style', 'text', 'Position', [20, 300, 100, 20], 'String', 'Sampling Rate (Hz):');
    samplingRateInput = uicontrol('Style', 'edit', 'Position', [130, 300, 200, 20], 'String', '12000');

    uicontrol('Style', 'text', 'Position', [20, 260, 100, 20], 'String', 'Hop Period (s):');
    hopPeriodInput = uicontrol('Style', 'edit', 'Position', [130, 260, 200, 20], 'String', '1.0');

    uicontrol('Style', 'text', 'Position', [20, 220, 100, 20], 'String', 'delta (Hz):');
    deltaFInput = uicontrol('Style', 'edit', 'Position', [130, 220, 200, 20], 'String', '100');

    % Create dropdown for selecting modulation type (2-FSK, 4-FSK, 8-FSK)
    uicontrol('Style', 'text', 'Position', [20, 180, 100, 20], 'String', 'Modulation Type:');
    modulationTypeMenu = uicontrol('Style', 'popupmenu', 'Position', [130, 180, 200, 20], ...
                                   'String', {'2-FSK', '4-FSK', '8-FSK'});

    % Axes for spectrogram
    spectrogramAxes = axes('Parent', fig, 'Position', [0.4, 0.1, 0.55, 0.8]);

    % Create buttons for generating and playing the signal
    uicontrol('Style', 'pushbutton', 'Position', [20, 140, 100, 30], 'String', 'Generate', ...
        'Callback', @generateSignal);
    uicontrol('Style', 'pushbutton', 'Position', [130, 140, 100, 30], 'String', 'Play', ...
        'Callback', @playSignal);

    % Variables to hold the generated signal and sampling rate
    fhssSignal = [];
    currentSamplingRate = 12000;

    % Callback function for generating the signal
    function generateSignal(~, ~)
        % Retrieve user inputs
        textMessage = get(textInput, 'String');
        currentSamplingRate = str2double(get(samplingRateInput, 'String'));
        hopPeriod = str2double(get(hopPeriodInput, 'String'));
        deltaF = str2double(get(deltaFInput, 'String'));
        modulationType = get(modulationTypeMenu, 'Value'); % Get selected modulation type

        if isempty(textMessage)
            errordlg('Text message cannot be empty.', 'Input Error');
            return;
        end

        % Generate the frequency table based on modulation type
        studentNumber = 2516581; % Replace with your student number
        freqTable = generateFreqTable(studentNumber, modulationType);

        % Generate the pilot signals
        pilotDuration = 0.5; % Duration of each pilot signal in seconds
        pilotFreq = 850; % Pilot signal frequency in Hz
        startPilot = generatePilotSignal(pilotFreq, pilotDuration, currentSamplingRate);
        endPilot = generatePilotSignal(pilotFreq, pilotDuration, currentSamplingRate);

        % Convert text to binary
        binaryData = textToBinary(textMessage);
        disp(binaryData)

        % Generate the FHSS signal
        fhssCoreSignal = generateFHSSSignal(binaryData, freqTable, deltaF, hopPeriod, currentSamplingRate, modulationType);

        % Combine start pilot, FHSS signal, and end pilot
        fhssSignal = [startPilot, fhssCoreSignal, endPilot];

        % Plot the spectrogram
        axes(spectrogramAxes); % Set current axes
        [~, F, T, P] = spectrogram(fhssSignal, 256, [], [], currentSamplingRate, 'yaxis');

        % Convert the magnitude to dB
        P_dB = 10 * log10(abs(P));

        % Plot the spectrogram with dB magnitude
        imagesc(T, F, P_dB);
        axis xy;
        xlabel('Time (s)');
        ylabel('Frequency (Hz)');
        title('Spectrogram of FHSS Signal with Start and End Pilots');
        colorbar;
        clim([-100 0]);  % Adjust color scale for better visualization
    end

    % Callback function for playing the signal
    function playSignal(~, ~)
        if isempty(fhssSignal)
            errordlg('Generate a signal first.', 'Playback Error');
            return;
        end
        sound(fhssSignal, currentSamplingRate);
    end

    % Supporting functions
    function pilotSignal = generatePilotSignal(freq, duration, samplingRate)
        t = 0:1/samplingRate:duration - 1/samplingRate;
        pilotSignal = sin(2 * pi * freq * t);
    end

    function freqTable = generateFreqTable(studentNumber, modulationType)
        % Generate the frequency table based on modulation type and student number.
        digits = num2str(studentNumber) - '0';
        N5 = digits(5);
        N6 = digits(6);
        N7 = digits(7);

        % Calculate b and S
        b = 1; % b = 1 if N5 is even; otherwise b = -1
        if mod(N5, 2) ~= 0
            b = -1;
        end
        S = 100 * N7; % S = 100 × N7

        % Generate frequency table for different categories based on modulation type
        if modulationType == 1 % 2-FSK
            b = 1; % b = 1 if N6 is even; otherwise b = -1
            if mod(N6, 2) ~= 0
                b = -1;
            end
            S = 100 * mod(N7, 5); % S = 100 × (N7 % 5)
            baseFreqs = [1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000];
            freqTable = baseFreqs + b * S;
        elseif modulationType == 2 % 4-FSK
            baseFreqs = [1500, 2500, 3500, 4500, 5500, 6500, 7500, 8500];
            freqTable = baseFreqs + b * S;
        elseif modulationType == 3 % 8-FSK
            baseFreqs = [1000, 3000, 5000, 7000, 9000, 11000];
            freqTable = baseFreqs + S;
        end
    end

    function binaryData = textToBinary(text)
        binaryData = reshape(dec2bin(text, 8)' - '0', 1, []); % Flatten into a binary vector
    end

    function signal = generateFHSSSignal(data, freqTable, deltaF, hopPeriod, samplingRate, modulationType)
        t = 0:1/samplingRate:hopPeriod - 1/samplingRate; % Time vector for one hop
        signal = []; % Initialize the full signal

        rng(1); % Set random seed for reproducibility
        numHops = length(data); % One hop for each bit
        hopOrder = randi(length(freqTable), 1, numHops); % Random indices for frequencies

        for i = 1:numHops
            hopFreq = freqTable(hopOrder(i));
            if modulationType == 1 % 2-FSK
                modFreq = hopFreq + (2 * data(i) - 1) * deltaF; % -deltaF or +deltaF
            elseif modulationType == 2 % 4-FSK
                modFreq = hopFreq + deltaF * (data(i) - 2); % Map to 4 frequencies
            elseif modulationType == 3 % 8-FSK
                modFreq = hopFreq + deltaF * (data(i) - 4); % Map to 8 frequencies
            end

            signal = [signal, sin(2 * pi * modFreq * t)];
        end
    end
end