classdef filterObj < handle
    % Filter object class inherited from handle master class to allow for
    % calling by reference properties, hence simplifying syntax
    
    properties (GetAccess=public)       % Public properties
        Type        % Descriptor for type of filter (string)
        Structure   % Descriptor for structure of filter (string)
        RealTF      % True if the transfer function is real-valued
    end
   
    properties (GetAccess=protected)    % Protected properties
        FsHz        % Sampling frequency in Hertz
        b           % Numerator coefficients of transfer function
        a           % Denominator coefficients of transfer function
        States      % Current states of filter
        %Cascade     % TODO: ask Tobias if necessary
    end
    
    properties (Dependent)              % Dependent properties
        Order       % Filter order
    end
    
    methods
        function [hLin,f] = frequencyResponse(fObj,nfft)
            %calcFilterResponse   Compute frequency response of filter objects.
            %
            %USAGE 
            %   [hlin,f] = calcFilterResponse(fObj,nfft)
            %
            %INPUT ARGUMENTS
            %   fObj : filter object(s) (see genFilterObj)
            %   nfft : resolution of frequency response
            %
            %OUTPUT ARGUMENTS
            %   hlin : Complex frequency response [nfft x 1]
            %      f : Frequency vector           [nfft x 1] 
            
            % CHECK INPUT ARGUMENTS 
            % 
            % 
            % Check for proper input arguments
            if nargin < 1 || nargin > 2
                help(mfilename);
                error('Wrong number of input arguments!')
            end
% 
%             % Unpack and check filter objects 
%             fObj = unpackFilterObj(fObj);

            % Set default frequency resolution
            if nargin < 2 || isempty(nfft); 
                if ~isempty(fObj.FsHz); 
                    % Sampling frequency is known
                    nfft = 2^nextpow2(fObj.FsHz * 50e-3); % TO DO: Ask Tobias about this "default", seems not to work when sampling frequency is one
                else
                    nfft = 512; 
                end
            end


            % *********************  COMPUTE FREQUENCY RESPONSE  *********************

            % Number of filter
%             nFilter = length(fObj);

            % Allocate memory
            hLin = zeros(nfft,1);

            
            if fObj.FsHz
                if fObj.RealTF
                    % Calculate frequency response of ii-th filter
                    [hLin(:),f] = freqz(fObj.b,fObj.a,nfft,fObj.FsHz);
                else
                    % TO DO: Is there a more elegant way to do things here?
                    ir = impz(fObj.b,fObj.a,nfft,fObj.FsHz);
                    [hLin(:),f] = freqz(2*real(ir),1,nfft,fObj.FsHz);
                end
            else
                % Calculate frequency response of ii-th filter
                % TO DO: Do we need that case?
                [hLin(:),f] = freqz(fObj.b,fObj.a,nfft);
            end
        end
        
        function h = plot(fObj,nfft,mode,handle)
            %plot   Plot frequency/phase response of a filter object.
            %
            %USAGE 
            %      h = fObj.plot()
            %      h = fObj.plot(nfft,mode)
            %      h = plot(fObj,nfft,mode)
            %
            %INPUT ARGUMENTS
            %   fObj : filter object 
            %   nfft : resolution of frequency response (default, 
            %          nfft = 512)
            %   mode : string specifying what to plot (default, mode = 'both')
            %          'magnitude' - plot magnitude response
            %              'phase' - plot phase response 
            %               'both' - plot both magnitude and phase response
            %            'impulse' - plot filter's impulse response
            % handle : handle to a previous filter object plot to visualize
            %          alongside other filters
            %
            %OUTPUT ARGUMENTS
            %   h : figure handle
            % 
            % TO DO: Finish use of handle for plotting on existing figure
            
            % CHECK INPUT ARGUMENTS 
            % 
            % 
            % Check for proper input arguments
            if nargin < 1 || nargin > 4
                help(mfilename);
                error('Wrong number of input arguments!')
            end

            % Set default values
            if nargin < 2 || isempty(nfft); nfft = [];     end
            if nargin < 3 || isempty(mode); mode = 'both'; end
            if nargin < 4 || isempty(handle); handle = []; end


            % COMPUTE FREQUENCY RESPONSE  
            % 
            % 
            % Compute filter response
            [hLin,f] = frequencyResponse(fObj,nfft);

            % Magnitude response in dB
            hdB = 20 * log10(abs(hLin));

            % Compute 10th and 90th percentile
            pct    = prctile(hdB,[5 95]);
            yRange = [-50 20];

            % Check if majority of data is within predefined range
            bSetY = pct(1) > yRange(1) && pct(2) < yRange(2);


            % PLOT FREQUENCY RESPONSE
            % 
            % 
            % Select mode
            switch lower(mode)
                case 'magnitude'
                    h = figure;
                    if fObj.FsHz
                        semilogx(f,hdB)
                        xlabel('Frequency (Hz)');
                        xlim([10 f(end)])
                    else
                        plot(f,hdB)
                        xlabel('Normalized frequency (x \pi rad/sample)');
                        xlim([f(1) f(end)])            
                    end
                    ylabel('Magnitude (dB)');
                    grid on;

                    % Show filter label
                    % TO DO: Investigate Type vs. Label
                    if ~isempty(fObj.Type); title(fObj.Type); end

                    if bSetY; ylim(yRange); end

                case 'phase'
                    phi = unwrap(angle(hLin)) * 180/pi;

                    h = figure;

                    if fObj.FsHz
                        semilogx(f,phi)
                        xlabel('Frequency (Hz)');
                        xlim([10 f(end)])
                    else
                        plot(f/pi,phi)
                        xlabel('Normalized frequency (x \pi rad/sample)');
                        xlim([0 0.5])            
                    end
                    ylabel('Phase (degree)');
                    grid on;

                    % Show filter label  % TO DO: Type vs. label
                    if ~isempty(fObj.Type); title(fObj.Type); end


                case 'both'
                    phi = unwrap(angle(hLin)) * 180/pi;

                    if isempty(handle)
                        h = figure;
                    else
                        h = figure(handle);
                        hold on
                    end
                    ax(1) = subplot(211);
                    if fObj.FsHz
                        semilogx(f,hdB)
                        xlabel('Frequency (Hz)');
                        xlim([10 f(end)])
                    else
                        plot(f/pi,hdB)
                        xlabel('Normalized frequency (x \pi rad/sample)');
                        xlim([0 0.5])            
                    end
                    ylabel('Magnitude (dB)');
                    grid on;

                    % Show filter label above the fist subplot % TO DO:
                    % Type vs. label
                    if ~isempty(fObj.Type); title(fObj.Type); end

                    if bSetY; ylim(yRange); end

                    ax(2) = subplot(212);

                    if fObj.FsHz
                        semilogx(f,phi)
                        xlabel('Frequency (Hz)');
                        xlim([10 f(end)])
                    else
                        plot(f/pi,phi)
                        xlabel('Normalized frequency (x \pi rad/sample)');
                        xlim([0 0.5])            
                    end
                    ylabel('Phase (degree)');
                    grid on;

                    linkaxes(ax,'x')
                otherwise
                    error(['Plotting mode "',lower(mode),'" is not supported.'])
            end
        end
        
        function out = filter(fObj,data)
            %filterAudio   Perform digital filtering of data/audio objects.
            %
            %USAGE 
            %   out = fObj.filterAudio(in)
            %
            %INPUT ARGUMENTS
            %     in : single channel audio 
            %   fObj : filter object
            %
            %OUTPUT ARGUMENTS
            %    out : filtered audio object or data matrix
            %
            % N.B: As fObj is inherited from the handle master class, the
            % filter properties (e.g., its states), will be updated
            %
            % TO DO: - Implement for multichannel filtering
            %        - Add other necessary filter structures
            
            % Check for proper input arguments
            if nargin ~= 2
                help(mfilename);
                error('Wrong number of input arguments!')
            end

            % Get dimensionality of data
            dim = size(data);
            
            % Select filtering method
            switch fObj.Structure
                case 'Direct-Form II Transposed'
                    filteringMethod = 'filter';
                otherwise
                    error(['Filter structure "',fObj.structure,'" is not recognized.'])
            end


            % *****************************  FILTERING  ******************************

            % *******************  CHECK FILTER COEFFICIENTS  *********************

            % Force filter coefficients to column vectors
%             fObj.b = fObj.b(:);
%             fObj.a = fObj.a(:);
%             
%             % Get dimension of filter coefficients
%             dimB = size(fObj.b);
%             dimA = size(fObj.a);

           

            % **********************  CHECK FILTER STATES  ************************

            % Check if filter states are initialized
            if isempty(fObj.States) 
                % Initialize filter states
                fObj.reset;
            elseif fObj.Order ~= size(fObj.States,1)
                error(['Dimension mismatch between the filter ',...
                       'coefficients and the filter states.']);
            end

            % TO DO: Extend filter states to the number of audio channls
%             if size(fObj.States,2) ~= dim(2:end)
%                 % Check if filter states are zero
%                 if sum(fObj.States) == 0 
%                     % Replicate filter states
%                     fObj.States = repmat(fObj.States,[1 dim(2:end)]);
%                 else
%                     error(['The dimensionality of the filter states - which ' ,...
%                            'are non-zero - does not match with the size of '  ,...
%                            'the input data! It seems that the dimensionality ',...
%                            'of the input data has changed during the last ',...
%                            'function call.']);
%                 end
%             end

            [out,fObj.States] = feval(filteringMethod,fObj.b,fObj.a,data,fObj.States);

            % TEST
%             b = [0.0300 0.0599 0.0300];
%             a = [1.0000 -1.4542 0.5741];
%             [out,fObj.States] = feval(filteringMethod,b,a,data,fObj.States);
            
            % Test to see if use of feval impairs computation time
%             [out,fObj.States] = filter(fObj.b,fObj.a,data,fObj.States);
            
            % Correction for complex-valued transfer function filters
            if ~(fObj.RealTF)
                out = 2*real(out);
            end
            
        end

        function order = get.Order(fObj)
            if isempty(fObj.a)||isempty(fObj.b)
                order = [];
            else
                order = max(length(fObj.b),length(fObj.a))-1;
            end
        end
        
        function reset(fObj)
            % This method resets the filter's states to zero
            if isempty(fObj.Order)
                error('The filter transfer function must have been specified before initializing its states')
            else
                % Create filter states
                fObj.States = zeros(fObj.Order,1);
            end
        end 
    end
    
    methods (Access=protected)
        function fObj = populateProperties(fObj,varargin)
            % TO DO : TO BE MOVED TO PROTECTED METHODS!!!
            
            % First check on input
            if mod(size(varargin,2),2)||isempty(varargin)
                error('Additional input arguments have to come in pairs of ...,''property name'',value,...')
            end
            
            % List of valid properties % TO DO: should this be hardcoded
            % here?
            validProp = {'Type',...
                         'Structure',...
                         'RealTF',...
                         'FsHz',...
                         'b',...
                         'a',...
                         'States',...
                         'Order'};
                     
            % Loop on the additional arguments
            for ii = 1:2:size(varargin,2)-1
                % Check that provided property name is a string
                if ~ischar(varargin{ii})
                    error('Property names should be given as strings, %s isn''t one!',num2str(varargin{ii}))
                end
                % Check that provided property name is valid
                if ~ismember(varargin{ii},validProp)
                    error('Property name ''%s'' is invalid',varargin{ii})
                end
                % Then add the property value
                fObj.(varargin{ii})=varargin{ii+1};
            end
            
            
        end 
    end
    
    
end