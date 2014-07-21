classdef gammatoneProc < Processor
    
    properties
        cfHz            % Filters center frequencies
        nERBs           % Distance between neighboring filters in ERBs
        n_gamma         % Gammatone order of the filters
        bwERBs          % Bandwidth of the filters in ERBs
        f_low           % Lowest center frequency used at instantiation
        f_high          % Highest center frequency used at instantiation
        fb_decimation   % Decimation ratio of the filterbank
    end
    
    properties (GetAccess = private)
        Filters         % Array of filter objects
    end
        
    methods
        function pObj = gammatoneProc(fs,flow,fhigh,nERBs,nChan,cfHz,irType,bAlign,...
                                        n,bw,durSec)
            %gammatoneProc      Construct a gammatone filterbank inheriting
            %                   the "processor" class
            %
            %USAGE
            % -Minimal usage, either (in order of priority)
            %   pObj = gammatoneProc(fs,[],[],[],[],cfHz)
            %   pObj = gammatoneProc(fs,flow,fhigh,[],nChan)
            %   pObj = gammatoneProc(fs,flow,fhigh,nERBs)
            %   pObj = gammatoneProc(fs,flow,fhigh)
            %
            % -Additional arguments:
            %   pObj = gammatoneProc(...,irType,bAlign,n,bw,dur)
            %
            %INPUT ARGUMENTS
            %     fs : Sampling frequency (Hz)
            %   flow : Lowest center frequency for the filterbank (in Hz)
            %  fhigh : Highest center frequency for the filterbank (in Hz)
            %  nERBs : Distance in ERBS between neighboring center
            %          frequencies (default: nERBS = 1)
            %  nChan : Number of channels
            %   cfHz : Vector of channels center frequencies
            %
            % irType : 'FIR' to generate finite impulse response Gammatone
            %          filters or 'IIR' for infinite (default: 'FIR')
            % bAlign : Set to true for phase correction and time alignment
            %          between channels (default: bAlign = false)
            %      n : Filter order (default: n = 4)
            %     bw : Bandwidth of the filters in ERBS 
            %          (default: bw = 1.08 ERBS)
            %    dur : Duration of the impulse response in seconds 
            %          (default: dur = 0.128)
            %
            %OUTPUT ARGUMENTS
            %   pObj : Processor object
            
            % TODO: 
            %  - Implement solution to allow for different impulse response
            %    durations for different filters (if necessary)
            %  - Implement bAlign option
            
            if nargin>0  % Failsafe for constructor calls without arguments
            
            % Checking input arguments
            if nargin < 3 || nargin > 11
                help(mfilename);
                error('Wrong number of input arguments!')
            end
            
            % Set default optional parameter
            if nargin < 11 || isempty(durSec); durSec = 0.128; end
            if nargin < 10 || isempty(bw); bw = 1.08; end
            if nargin < 9 || isempty(n); n = 4; end
            if nargin < 8 || isempty(bAlign); bAlign = false; end
            if nargin < 7 || isempty(irType); irType = 'FIR'; end
            
            % Parse mandatory arguments: three scenarios
            
            if ~isempty(cfHz)
                % 3- A vector of channels center frequencies is provided
                
                % Do nothing, we already have a vector of center
                % frequencies in Hz
                
                % Give a warning to the user though if he specified other
                % conflicting properties
%                 if ~isempty(flow)||~isempty(fhigh)||~isempty(nChan)||~isempty(nERBs)
%                     warning(['Conflicting parameters were provided for '...
%                         'the Gammatone filterbank instantiation. The '...
%                         'filterbank will be generated from the provided'...
%                         ' list of center frequencies.'])
%                 end
                
            elseif ~isempty(flow)&&~isempty(fhigh)&&~isempty(nChan)
                % 2- Frequency range and number of channels is provided
                
                % Give a warning if conflicting properties were specified
%                 if ~isempty(nERBs)
%                     warning(['Conflicting parameters were provided for '...
%                         'the Gammatone filterbank instantiation. The '...
%                         'filterbank will be generated from the provided'...
%                         ' frequency range and number of channels.']) 
%                 end
                
                % Get vector of center frequencies
                ERBS = linspace(freq2erb(flow),freq2erb(fhigh),nChan);  % In ERBS
                cfHz = erb2freq(ERBS);                                  % In Hz
                
            elseif ~isempty(flow)&&~isempty(fhigh)&&isempty(nChan)&&isempty(cfHz)
                % 3- Frequency range and distance between channels is provided
                
                % Set distance between two channel to default is unspecified
                if nargin < 4 || isempty(nERBs);  nERBs  = 1;     end
                
                % Get vector of center frequencies
                ERBS = freq2erb(flow):double(nERBs):freq2erb(fhigh);    % In ERBS
                cfHz = erb2freq(ERBS);                                  % In Hz
                
            else
                % Else, something is missing in the input
                error('Not enough or incoherent input arguments.')
            end
            
            
            % Number of gammatone filters
            nFilter = numel(cfHz); 
            
            % Instantiating the filters
            pObj.Filters = pObj.populateFilters(cfHz,fs,irType,n,bw,...
                            bAlign,durSec);
            
            % Setting up additional properties
            % 1- Global properties
            populateProperties(pObj,'Type','Gammatone filterbank',...
                'Dependencies',getDependencies('gammatone'),...
                'FsHzIn',fs,'FsHzOut',fs);
            % 2- Specific properties
            pObj.cfHz = cfHz;
            pObj.nERBs = nERBs;
            pObj.n_gamma = n;
            pObj.bwERBs = bw;
            pObj.f_low = flow;
            pObj.f_high = fhigh;
            pObj.fb_decimation = 1;
            
            end
        end
        
        function out = processChunk(pObj,in)
            %processChunk       Passes an input signal through the
            %                   Gammatone filterbank
            %
            %USAGE
            %       out = processChunk(pObj,in)
            %       out = pObj.processChunk(in)
            %
            %INPUT ARGUMENTS
            %      pObj : Gammatone filterbank object
            %        in : One-dimensional array containing the input signal
            %
            %OUTPUT ARGUMENTS
            %       out : Multi-dimensional array containing the filterbank
            %             outputs
            %
            %SEE ALSO:
            %       gammatoneProc.m
            
            % TO DO: Indicate that this function is not buit to deal with
            % multiple channels. Multiple channels should be treated with
            % multiple instances of the filterbank.
            
            % Check inputs
            if min(size(in))>1
                error('The input should be a one-dimensional array')
            end
            
            % Turn input into column vector
            in = in(:);
            
            % Get number of channels
            nFilter = size(pObj.Filters,2);
            
            % Pre-allocate memory
            out = zeros(length(in),nFilter);
            
            % Loop on the filters
            for ii = 1:nFilter
                out(:,ii) = pObj.Filters(ii).filter(in);
            end
            
            % TO DO : IMPLEMENT ALIGNMENT CORRECTION
            
        end
        
        function reset(pObj)
            %reset          Order the processor to reset its internal
            %               states, e.g., when some critical parameters in
            %               the processing have been changed
            %USAGE
            %       pObj.reset()
            %       reset(pObj)
            %
            %INPUT ARGUMENT
            %       pObj : Processor object
            
            nFilter = size(pObj.Filters,2);
            
            % Resetting the internal states of the filters
            for ii = 1:nFilter
                pObj.Filters(ii).reset();
            end
            
        end
        
        function hp = hasParameters(pObj,p)
            %hasParameters  This method compares the parameters of the
            %               processor with the parameters given as input
            %
            %USAGE
            %    hp = pObj.hasParameters(p)
            %
            %INPUT ARGUMENTS
            %  pObj : Processor instance
            %     p : Structure containing parameters to test
            
            %NB: Could be moved to private
            
            % There are three ways to initialize a gammatone filterbank, of
            % which only the center frequencies of the channel is in
            % common. Hence only this parameter is checked regarding
            % channel positionning.
            
            p_list = {'cfHz','n_gamma','bwERBs'};
            
            % The center frequency position needs to be computed for
            % scenario where it is not explicitely provided
            if isempty(p.cfHz)&&~isempty(p.nChannels)
                ERBS = linspace(freq2erb(p.f_low),freq2erb(p.f_high),p.nChannels);    % In ERBS
                p.cfHz = erb2freq(ERBS);                                              % In Hz
            elseif isempty(p.cfHz)&&isempty(p.nChannels)
                ERBS = freq2erb(p.f_low):double(p.nERBs):freq2erb(p.f_high);   % In ERBS
                p.cfHz = erb2freq(ERBS);                                       % In Hz
            end
            
            
            % Initialization of a parameters difference vector
            delta = zeros(size(p_list,2),1);
            
            % Loop on the list of parameters
            for ii = 1:size(p_list,2)
                try
                    if size(pObj.(p_list{ii}))==size(p.(p_list{ii}))
                        delta(ii) = max(abs(pObj.(p_list{ii}) - p.(p_list{ii})));
                    else
                        delta(ii) = 1;
                    end
                    
                catch err
                    % Warning: something is missing
                    warning('Parameter %s is missing in input p.',p_list{ii})
                    delta(ii) = 1;
                end
            end
            
            % Check if delta is a vector of zeros
            if max(delta)>0
                hp = false;
            else
                hp = true;
            end
            
        end  
        
    end
    
    methods (Access = private)
        function obj = populateFilters(pObj,cfHz,fs,irType,n,bw,bAlign,durSec)
            % This function is a workaround to assign an array of objects
            % as one of the processor's property, should remain private

            nFilter = numel(cfHz);
            
            % Preallocate memory by instantiating last filter
            obj(1,nFilter) = gammatoneFilter(cfHz(nFilter),fs,irType,n,...
                                        bw,bAlign,durSec);
            % Instantiating remaining filters
            for ii = 1:nFilter-1
                obj(1,ii) = gammatoneFilter(cfHz(ii),fs,irType,n,...
                                        bw,bAlign,durSec);
            end                        
            
        end
    end
        
end