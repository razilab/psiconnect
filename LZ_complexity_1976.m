function c = LZ_complexity_1976(s)
    % Calculate Lempel-Ziv's algorithmic complexity using the LZ76 algorithm
    % and the sliding-window implementation.
    %
    % Reference:
    % F. Kaspar, H. G. Schuster, "Easily-calculable measure for the
    % complexity of spatiotemporal patterns", Physical Review A, Volume 36,
    % Number 2 (1987).
    %
    % Input:
    %   s -- list of integers
    %
    % Output:
    %   c -- integer

    % Flatten the array and convert to row vector
    s = s(:)'; 
    n = length(s);
    
    if n == 0
        c = 0; return;
    end
    
    % Initialize variables
    i = 0; k = 1; l = 1;
    c = 1; k_max = 1;
    
    % Main loop to calculate complexity
    while true
        % Check if current characters match
        if s(i + k) == s(l + k)
            k = k + 1; % Increment length of matching substring
            % If end of sequence is reached, increment complexity and break
            if l + k > n
                c = c + 1;
                break;
            end
        else
            % Update maximum length of matching substring
            if k > k_max
                k_max = k;
            end
            i = i + 1; % Move starting position of first substring
            % If i reaches l, increment complexity and update l
            if i == l
                c = c + 1;
                l = l + k_max;
                % If end of sequence is reached, break
                if l + 1 > n
                    break;
                else
                    % Reset variables for next iteration
                    i = 0;
                    k = 1;
                    k_max = 1;
                end
            else
                k = 1; % Reset length of matching substring
            end
        end
    end
end