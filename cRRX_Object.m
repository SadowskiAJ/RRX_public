classdef cRRX_Object
    properties
        sHex64 % Anonymous hex code ID of submission

        sCPU_string % CPU original string
        sCPU_gen % CPU generation
        sCPU_ISA % ISA code

        sOS_name % OS name
        sOS_edition % OS edition
        sOS_build % OS build

        sAbaqus_version % Abaqus version
        sAbaqus_build % Abaqus build
        
        sRAM_class % RAM class
        sRAM_transferrate % RAM transfer rate in MT/s or MHz

        cMNA_Block
        cGNA1_Block
        cGNA2_Block
        cGNA3_Block      

        sSubmissionFingerprint
    end
    
    methods
        function obj = cRRX_Object(file_name) % Constructor
            if nargin == 0; return; end % Allow empty constructor for array preallocation
            obj.sHex64 = obj.ParseHex64(file_name);

            fid = fopen(file_name, 'r');
            if fid < 0; error('Could not open file: %s', file_name); end
            fileCleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

            % Metadata occupies exactly four lines; do not consume an
            % analysis header as metadata in a truncated submission.
            metadata = cell(1, 4);
            for i = 1:4
                line = fgetl(fid);
                if isequal(line, -1)
                    error('cRRX_Object:MissingMetadata', ...
                        'Missing metadata line %d in %s.', i, file_name);
                end
                if i == 1; line = erase(line, char(65279)); end % UTF-8 BOM
                if startsWith(strtrim(line), '#')
                    error('cRRX_Object:MissingMetadata', ...
                        'Analysis header encountered at metadata line %d in %s.', i, file_name);
                end
                metadata{i} = line;
            end
            obj.sCPU_string = metadata{1};
            [obj.sCPU_gen, obj.sCPU_ISA] = obj.ParseCPU(metadata{1});
            [obj.sOS_name, obj.sOS_edition, obj.sOS_build] = obj.ParseOS(metadata{2});
            [obj.sAbaqus_version, obj.sAbaqus_build] = obj.ParseAbaqus(metadata{3});
            [obj.sRAM_class, obj.sRAM_transferrate] = obj.ParseRAM(metadata{4});

            headers = {'#MNA', '#GNA1', '#GNA2', '#GNA3'};
            fields = {'cMNA_Block', 'cGNA1_Block', 'cGNA2_Block', 'cGNA3_Block'};
            seen = false(1, 4);
            while ~feof(fid)
                line = fgetl(fid);
                if isequal(line, -1); break; end
                line = strtrim(line);
                if isempty(line); continue; end
                index = find(strcmpi(line, headers), 1);
                if isempty(index)
                    error('cRRX_Object:UnexpectedLine', ...
                        'Unexpected section header or text in %s: %s', file_name, line);
                end
                if seen(index)
                    error('cRRX_Object:DuplicateBlock', ...
                        'Duplicate %s section in %s.', headers{index}, file_name);
                end
                try
                    obj.(fields{index}) = obj.ParseBlock(fid);
                catch ME
                    context = MException('cRRX_Object:InvalidBlock', ...
                        'Failed to read %s in %s.', headers{index}, file_name);
                    throw(addCause(context, ME));
                end
                seen(index) = true;
            end

            if ~all(seen)
                error('cRRX_Object:MissingBlock', ...
                    'Missing section(s) in %s: %s.', file_name, strjoin(headers(~seen), ', '));
            end
            obj.sSubmissionFingerprint = obj.Fingerprint();
        end

        function out = CheckSums(obj, X)
            out = [obj.cMNA_Block.CheckSum(X) obj.cGNA1_Block.CheckSum(X) obj.cGNA2_Block.CheckSum(X) obj.cGNA3_Block.CheckSum(X)];
        end
    end

    methods (Access = private)
        function str = ParseHex64(~, file_name)
            % Parse the hex code from the given file
            [~, str, ~] = fileparts(file_name);
        end

        function out = Fingerprint(obj)
            fingerprints = {
                obj.cMNA_Block.sFingerprint
                obj.cGNA1_Block.sFingerprint
                obj.cGNA2_Block.sFingerprint
                obj.cGNA3_Block.sFingerprint
            };
        
            % Initialise empty SHA-256 cryptographic accumulator
            md = java.security.MessageDigest.getInstance('SHA-256');
        
            for i = 1:numel(fingerprints)
                hexFingerprint = fingerprints{i};
        
                % Validate the stored hexadecimal representation.
                if ~ischar(hexFingerprint) || numel(hexFingerprint) ~= 64
                    error('Invalid block fingerprint.');
                end
        
                % Convert 64 hexadecimal characters back to 32 uint8 bytes.
                digestBytes = uint8(sscanf(hexFingerprint, '%2x').');       
                if numel(digestBytes) ~= 32; error('Invalid block fingerprint.'); end
        
                % Reinterpret the unsigned bytes as Java signed bytes.
                md.update(typecast(digestBytes, 'int8'));        
            end
        
            % Finalise the submission-level SHA-256.
            digestBytes = typecast(md.digest(), 'uint8');
            out = lower(reshape(dec2hex(digestBytes, 2).', 1, []));            
        end

        function [cpu, isa] = ParseCPU(~, sLine)
            % ParseCPU  Extract canonical CPU architecture and ISA class from a messy CPU string.
            % Returns:
            %   cpu  - architecture family (e.g., 'Intel Raptor Lake')
            %   isa  - ISA class code (e.g., 'INTEL_AVX2_HYBRID')
            
            s = lower(strtrim(sLine));
            
            %% ------------------------------------------------------------
            %  Vendor detection (robust, does NOT require "Intel" or "AMD")
            %% ------------------------------------------------------------
            isIntel = contains(s,'intel') || ...
                      contains(s,'i3-') || contains(s,'i5-') || ...
                      contains(s,'i7-') || contains(s,'i9-') || ...
                      contains(s,'xeon') || contains(s,'core ultra') || ...
                      contains(s,'ultra') || contains(s,'w-') || ...
                      contains(s,'e5-');
            
            isAMD = contains(s,'amd') || ...
                    contains(s,'ryzen') || contains(s,'epyc') || ...
                    contains(s,'threadripper') || contains(s,'ai ') || ...
                    contains(s,'ai-');
            
            %% ------------------------------------------------------------
            %  INTEL
            %% ------------------------------------------------------------
            if isIntel                           
                % -------- Meteor Lake (Core Ultra 1xx / 2xx) --------
                if contains(s,'ultra') || contains(s,'core ultra')
                    cpu = 'Intel Meteor Lake';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end

                % -------- Nova Lake (18th gen, Core Ultra 5xx) --------
                if contains(s,'core ultra') && contains(s,'5')
                    cpu = 'Intel Nova Lake';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end

                % -------- Panther Lake (17th gen, Core Ultra 4xx) --------
                if contains(s,'core ultra') && contains(s,'4')
                    cpu = 'Intel Panther Lake';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end

                % -------- Lunar Lake (16th gen, Core Ultra 3xx) --------
                if contains(s,'core ultra') && contains(s,'3')
                    cpu = 'Intel Lunar Lake';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end


                % -------- Arrow Lake (15th gen, Core Ultra 2xx) --------
                if contains(s,'core ultra') && contains(s,'2')
                    cpu = 'Intel Arrow Lake';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end

                % -------- Raptor Lake Refresh (14th gen) --------
                if contains(s,'14th gen') || contains(s,'-14')
                    cpu = 'Intel Raptor Lake Refresh';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end
            
                % -------- Raptor Lake (13th gen) --------
                if contains(s,'13th gen') || contains(s,'-13')
                    cpu = 'Intel Raptor Lake';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end
            
                % -------- Alder Lake (12th gen) --------
                if contains(s,'12th gen') || contains(s,'-12')
                    cpu = 'Intel Alder Lake';
                    isa = 'INTEL_AVX2_HYBRID';
                    return;
                end
            
                % -------- Comet Lake (10th gen) --------
                if contains(s,'10th gen') || contains(s,'-10')
                    cpu = 'Intel Comet Lake';
                    isa = 'INTEL_AVX2_MONOLITHIC';
                    return;
                end
            
                % -------- Tiger Lake / Ice Lake (client AVX-512) --------
                if contains(s,'11th gen') || contains(s,'i7-11') || contains(s,'i5-11')
                    cpu = 'Intel Tiger/Ice Lake';
                    isa = 'INTEL_AVX512_CLIENT';
                    return;
                end
            
                % -------- Cascade Lake-W / X (AVX-512 server/HEDT) --------
                if contains(s,'w-22') || contains(s,'-62') || contains(s,'-82')
                    cpu = 'Intel Cascade Lake-W/X';
                    isa = 'INTEL_AVX512_SERVER';
                    return;
                end
            
                % -------- Haswell-E (E5-16xx v3) --------
                if contains(s,'e5-16') && contains(s,'v3')
                    cpu = 'Intel Haswell-E';
                    isa = 'INTEL_AVX_LEGACY';
                    return;
                end
            
                % -------- Skylake/Kaby/Coffee fallback --------
                if contains(s,'i7-7') || contains(s,'i7-8') || contains(s,'i7-9') || ...
                   contains(s,'i5-7') || contains(s,'i5-8') || contains(s,'i5-9')
                    cpu = 'Intel Skylake/Kaby/Coffee Lake';
                    isa = 'INTEL_AVX2_MONOLITHIC';
                    return;
                end
            
                % If we reach here, Intel but unknown pattern
                cpu = 'Intel (Unknown Generation)';
                isa = 'INTEL_AVX2_MONOLITHIC';
                return;
            end
            
            %% ------------------------------------------------------------
            %  AMD
            %% ------------------------------------------------------------
            if isAMD
            
                % -------- Zen 5 (Ryzen AI 300, Ryzen 9000) --------
                if contains(s,'ai 3') || contains(s,'9000')
                    cpu = 'AMD Zen 5';
                    isa = 'AMD_ZEN5';
                    return;
                end
            
                % -------- Zen 4 (Ryzen 7000, TR 7000, EPYC 9xx4) --------
                if contains(s,'7955') || contains(s,'79') || ...
                   (contains(s,'epyc') && contains(s,'9'))
                    cpu = 'AMD Zen 4';
                    isa = 'AMD_ZEN4';
                    return;
                end
            
                % -------- Zen 3 (Ryzen 5000, EPYC 7xx3) --------
                if contains(s,'5800') || contains(s,'7543') || ...
                   (contains(s,'epyc') && contains(s,'7'))
                    cpu = 'AMD Zen 3';
                    isa = 'AMD_ZEN3';
                    return;
                end
            
                % -------- Zen 2 (Ryzen 3000, EPYC 7xx2) --------
                if contains(s,'3') && contains(s,'ryzen')
                    cpu = 'AMD Zen 2';
                    isa = 'AMD_ZEN2';
                    return;
                end
            
                % Fallback
                cpu = 'AMD (Unknown Generation)';
                isa = 'AMD_ZEN3';
                return;
            end
            
            %% ------------------------------------------------------------
            %  Unknown vendor
            %% ------------------------------------------------------------
            cpu = 'Unknown CPU';
            isa = 'UNKNOWN_ISA';      
        end

        function [os, edition, build] = ParseOS(~, sLine)
            % ParseOS  Extract canonical OS family, edition, and build/kernel version
            % from a messy OS string.
            
            s = lower(strtrim(sLine));
            
            os = 'Unknown OS';
            edition = 'Unknown Edition';
            build = '';
            
            %% ------------------------------------------------------------
            %  WINDOWS DETECTION
            %% ------------------------------------------------------------
            isWindows = contains(s,'windows') || contains(s,'window'); % catch typos
            
            if isWindows
            
                % ---------------- Windows 11 ----------------
                if contains(s,'11')
                    os = 'Windows 11';
                elseif contains(s,'10')
                    os = 'Windows 10';
                else
                    os = 'Windows (Unknown Version)';
                end
            
                % ---------------- Edition detection ----------------
                if contains(s,'enterprise') || contains(s,'erterprise')
                    edition = 'Enterprise';
                elseif contains(s,'pro')
                    edition = 'Pro';
                elseif contains(s,'home')
                    edition = 'Home';
                elseif contains(s,'ltsc')
                    edition = 'LTSC';
                else
                    edition = 'Unknown Edition';
                end
            
                % ---------------- Build number extraction ----------------
                % Match patterns like 26100, 26200, 19045.6466, 17763
                tokens = regexp(s, '(\d{5}(?:\.\d+)?)', 'tokens');
                if ~isempty(tokens)
                    build = tokens{1}{1};
                end
            
                return;
            end
            
            %% ------------------------------------------------------------
            %  LINUX DETECTION
            %% ------------------------------------------------------------
            
            % ---------------- Rocky Linux / RHEL clones ----------------
            if contains(s,'rocky') || contains(s,'rhel') || contains(s,'el8')
                os = 'Rocky Linux 8';
                edition = 'Standard';
            
                % Extract kernel version
                tokens = regexp(s, 'kernel\s*([\d\.\-\_a-z]+)', 'tokens');
                if ~isempty(tokens)
                    build = tokens{1}{1};
                end
                return;
            end
            
            % ---------------- Ubuntu ----------------
            if contains(s,'ubuntu')
                os = 'Ubuntu';
                edition = 'Standard';
            
                tokens = regexp(s, '([\d]+\.[\d]+(\.[\d]+)?)', 'tokens');
                if ~isempty(tokens)
                    build = tokens{1}{1};
                end
                return;
            end
            
            % ---------------- Debian ----------------
            if contains(s,'debian')
                os = 'Debian';
                edition = 'Standard';
                return;
            end
            
            % ---------------- CentOS ----------------
            if contains(s,'centos')
                os = 'CentOS';
                edition = 'Standard';
                return;
            end
            
            %% ------------------------------------------------------------
            %  UNKNOWN OS
            %% ------------------------------------------------------------
            os = 'Unknown OS';
            edition = 'Unknown Edition';
            build = '';
        
        end
        
        function [version, build] = ParseAbaqus(~, sLine)
            % ParseAbaqus  Extract Abaqus version year and build number from messy strings.
            
            % --- Normalise string (critical!) ---
            s = lower(strtrim(sLine));
            s = regexprep(s, '[^\x20-\x7E]', ' ');   % remove non-ASCII
            s = regexprep(s, '\s+', ' ');           % collapse whitespace
            
            version = 'Unknown Abaqus Version';
            build   = '';
            
            %% ------------------------------------------------------------
            %  Extract a four-digit release year (2000–2099)
            %% ------------------------------------------------------------
            yearTok = regexp(s, '(?<!\d)(20\d{2})(?!\d)', 'tokens');
            
            if ~isempty(yearTok)
                year = yearTok{1}{1};
                version = ['Abaqus ' year];
            end
            
            %% ------------------------------------------------------------
            %  Extract build number (5–6 digit integer)
            %% ------------------------------------------------------------
            % Matches: 190762, 183150, 198590, 183566, etc.
            buildTok = regexp(s, '(\d{5,6})', 'tokens');
            
            if ~isempty(buildTok)
                % Abaqus build number is ALWAYS the last 5–6 digit number in the string
                build = buildTok{end}{1};
                return;
            end
            
            %% ------------------------------------------------------------
            %  Extract build from full build stamp (RELr426 190762)
            %% ------------------------------------------------------------
            stampTok = regexp(s, 'rel[a-z0-9\.\-\_ ]+(\d{5,6})', 'tokens');
            if ~isempty(stampTok)
                build = stampTok{1}{1};
                return;
            end
        end

        function [ramClass, transferRateMTs] = ParseRAM(~, sLine)
            % ParseRAM  Extract RAM class (DDR4/DDR5/LPDDR5) and transfer rate in MT/s.
            % Returns:
            %   ramClass        - 'DDR4', 'DDR5', 'LPDDR5', etc.
            %   transferRateMTs - numeric MT/s value (MHz converted automatically)
            
            s = lower(strtrim(sLine));
            
            % Normalise string
            s = regexprep(s, '[^\x20-\x7E]', ' ');   % remove non-ASCII
            s = regexprep(s, '\s+', ' ');           % collapse whitespace
            
            %% ------------------------------------------------------------
            %  Detect RAM class
            %% ------------------------------------------------------------
            if contains(s,'lpddr5')
                ramClass = 'LPDDR5';
            elseif contains(s,'ddr5')
                ramClass = 'DDR5';
            elseif contains(s,'ddr4')
                ramClass = 'DDR4';
            elseif contains(s,'ddr3')
                ramClass = 'DDR3';
            else
                ramClass = 'Unknown RAM';
            end
            
            %% ------------------------------------------------------------
            %  Extract numeric speed (first 3–5 digit number)
            %% ------------------------------------------------------------
            tok = regexp(s, '(\d{3,5})', 'tokens');
            
            if isempty(tok)
                transferRateMTs = NaN;
                return;
            end
            
            speed = str2double(tok{1}{1});
            
            %% ------------------------------------------------------------
            %  Determine units and convert to MT/s
            %% ------------------------------------------------------------
            if contains(s,'mhz')
                % DDR: MT/s = MHz (double data rate already accounted for)
                transferRateMTs = speed;
            else
                % MT/s or unspecified → assume MT/s
                transferRateMTs = speed;
            end
        end

        function block = ParseBlock(~, fid)
            % Parse a block of data from the file
            block = cBlock_Object(fid); 
        end
    end
end
