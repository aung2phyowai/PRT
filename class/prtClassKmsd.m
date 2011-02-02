classdef prtClassKmsd < prtClass
    % prtClassKmsd  Kernel matched subspace detector classifier
    %
    %    CLASSIFIER = prtClassKmsd returns a Kmsd classifier
    %
    %    CLASSIFIER = prtClassKmsd(PROPERTY1, VALUE1, ...) constructs a
    %    prtClassKmsd object CLASSIFIER with properties as specified by
    %    PROPERTY/VALUE pairs.
    %
    %    A prtClassKmsd object inherits all properties from the abstract class
    %    prtClass. In addition is has the following properties:
    %
    %    sigma  - Inverse kernel width for guassian radial basis function
    % 
    %    For more information on Kmsd classifiers, refer to the
    %    following URL:
    %  
    %    http://ieeexplore.ieee.org/xpl/freeabs_all.jsp?arnumber=1561179
    %
    %    A prtClassKmsd object inherits the TRAIN, RUN, CROSSVALIDATE and
    %    KFOLDS methods from prtAction. It also inherits the PLOT method
    %    from prtClass.
    %
    %    Example:
    %
    %     TestDataSet = prtDataGenUnimodal;       % Create some test and
    %     TrainingDataSet = prtDataGenUnimodal;   % training data
    %     classifier = prtClassKmsd;              % Create a classifier
    %     classifier = classifier.train(TrainingDataSet);    % Train
    %     classified = run(classifier, TestDataSet);         % Test
    %     classifier.plot;
    %
    %    See also prtClass, prtClassLogisticDiscriminant, prtClassBagging,
    %    prtClassMap, prtClassCap, prtClassBinaryToMaryOneVsAll, prtClassDlrt,
    %    prtClassPlsda, prtClassFld, prtClassRvm, prtClassKmsd,  prtClass
    
    properties (SetAccess=private)
        % Required by prtAction
        name = 'Kernel matched subspace detector'  % Kernel matched subspace detector
        nameAbbreviation = 'KMSD'  % KMSD
        isNativeMary = false;   % False
    end
    properties (Access = private, Hidden = true)
        % Target libaray
        Zt = [];
        % Background library
        Zb = [];
        
        Ztb   = [];
        Delta = [];
        Beta  = [];
        Tau   = [];
        Kb_t  = [];
        Kt_b  = [];
        Kt_t  = [];
        Kb_b  = [];
    end
    
    properties
        sigma = .01;  % Kernel parameter for radial basis function   
    end
    
    methods
        function Obj = prtClassKmsd(varargin)
            
            Obj = prtUtilAssignStringValuePairs(Obj,varargin{:});
        end
        
        function Obj = set.sigma(Obj,val)
            if ~prtUtilIsPositiveScalar(val)
                error('prt:prtClassKmsd:sigma','sigma must be a positive scalar');
            end
            Obj.sigma = val;
        end
    end
    
    methods (Access=protected, Hidden = true)
        
        function Obj = trainAction(Obj,DataSet)
            
            Obj.Zt = DataSet.getObservationsByClass(1);
            Obj.Zb = DataSet.getObservationsByClass(0);
            
            Obj.Ztb = [Obj.Zt; Obj.Zb];
            
            % Compute Delta
           % Ktb_tb = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Ztb,Obj.Ztb,sqrt(Obj.sigma));
            Ktb_tb = Obj.rbfKernel(Obj.Ztb,Obj.Ztb,Obj.sigma);
            [Obj.Delta eigD] = eig(Ktb_tb);
           
            eigD = diag(eigD);
            sumD = sum(eigD);
            eigNorm = eigD/sumD;
            eigPow = cumsum(flipud(eigNorm));
            idx = find(eigPow>.9);   % 90% eigenvectors works well
            Obj.Delta = Obj.Delta(:,end-idx:end);
            
            
            % Compute Tau
            %Obj.Kt_t = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Zt,Obj.Zt,sqrt(Obj.sigma));
            Obj.Kt_t = Obj.rbfKernel(Obj.Zt,Obj.Zt,Obj.sigma);
            [Obj.Tau, eigT] = eig(Obj.Kt_t);
            eigT = diag(eigT);
            sumT = sum(eigT);
            eigNorm = eigD/sumT;
            eigPow = cumsum(flipud(eigNorm));
            idx = find(eigPow>.9);
            Obj.Tau = Obj.Tau(:,end-idx:end);
            
            
            % Compute Beta
            %Obj.Kb_b = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Zb,Obj.Zb,sqrt(Obj.sigma));
            Obj.Kb_b = Obj.rbfKernel(Obj.Zb,Obj.Zb,Obj.sigma);
            [Obj.Beta, eigB] = eig(Obj.Kb_b);
            %Use eigenvectors that correspond to 90 of the information
            eigB = diag(eigB);
            sumB = sum(eigB);
            eigNorm = eigB/sumB;
            eigPow = cumsum(flipud(eigNorm));
            idx = find(eigPow>.90);
            Obj.Beta = Obj.Beta(:,end-idx:end);
            
            % Compute these too just for fun
            %Obj.Kb_t = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Zb,Obj.Zt,sqrt(Obj.sigma));
            Obj.Kb_t = Obj.rbfKernel(Obj.Zb,Obj.Zt,Obj.sigma);
            %Obj.Kt_b = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Zt,Obj.Zb,sqrt(Obj.sigma));
            Obj.Kt_b = Obj.rbfKernel(Obj.Zt,Obj.Zb,Obj.sigma);
            
     end
        
        function ClassifierResults = runAction(Obj,DataSet)
            
            y = DataSet.getObservations();
            memLimSamples = 1000;
            if size(y,1) < memLimSamples
                dataOut = diag(prtClassKmsd.prtClassRunKMSD(Obj,y));
                ClassifierResults = prtDataSetClass(dataOut);
            else
                dataOut = [];
                maxSamples = size(y,1);
                currInd = 1;
                while currInd <= maxSamples
                    currIndices = currInd:min([currInd+memLimSamples-1,maxSamples]);
                    currData = y(currIndices,:);
                    dataOut = cat(1,dataOut,diag(prtClassKmsd.prtClassRunKMSD(Obj,currData)));
                    currInd = currInd + memLimSamples;
                end
                ClassifierResults = prtDataSetClass(dataOut);
            end
        end
        
    end
    methods (Static,Hidden = true)
        function LRT = prtClassRunKMSD(Obj,y)
            % Performs kmsd Classification on samples y. Zt is the target library. Zb is the
            % background library sigma is the RBF parameter.
            
 
            % Compute the emperical kernel maps
            %Ktb_y = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Ztb,y,sqrt(Obj.sigma));
            Ktb_y = Obj.rbfKernel(Obj.Ztb,y,Obj.sigma);
            %Kb_y  = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Zb,y,sqrt(Obj.sigma));
            Kb_y  = Obj.rbfKernel(Obj.Zb,y,Obj.sigma);
            %Kt_y  = prtKernelRbfNdimensionScale.rbfEvalKernel(Obj.Zt,y,sqrt(Obj.sigma));
            Kt_y  = Obj.rbfKernel(Obj.Zt,y,Obj.sigma);
            % Compute the numerator of eq 32
            Num = Ktb_y'*(Obj.Delta*Obj.Delta')* Ktb_y - Kb_y'*(Obj.Beta*Obj.Beta')*Kb_y;
            
            % Compute Gamma1
            Gamma = [Obj.Tau'*Obj.Kt_t*Obj.Tau Obj.Tau'*Obj.Kt_b*Obj.Beta; Obj.Beta'*Obj.Kb_t*Obj.Tau Obj.Beta'*Obj.Kb_b*Obj.Beta];
            
            % Compute the denominator of eq 32
            %Den = Ktb_y'*(Obj.Delta*Obj.Delta')*Ktb_y - [Kt_y'*Obj.Tau Kb_y'*Obj.Beta] * inv(Gamma) * [Obj.Tau'*Kt_y;Obj.Beta'*Kb_y];
            Den = Ktb_y'*(Obj.Delta*Obj.Delta')*Ktb_y - [Kt_y'*Obj.Tau Kb_y'*Obj.Beta] /(Gamma) * [Obj.Tau'*Kt_y;Obj.Beta'*Kb_y];
            
            LRT = Num./Den;
        end
        function [gram,nBasis] = rbfKernel(x1,x2,sigma)
            
            [N1, d] = size(x1);
            [N2, nin] = size(x2);
            if d ~= nin
                error('size(x1,2) must equal size(x2,2)');
            end
            dist2 = repmat(sum((x1.^2)', 1), [N2 1])' + ...
                repmat(sum((x2.^2)',1), [N1 1]) - ...
                2*x1*(x2'); %#ok<UDIM>
            gram = exp(-dist2/(nin*sigma));
            
            nBasis = size(gram,2);
            
        end
    end
    
end