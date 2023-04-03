# Data-Leakage-From-Covariances
Federated Learning (FL) is gaining traction in various fields as it enables integrative data analysis without sharing sensitive data, such as in healthcare. However, the risk of data leakage caused by malicious attacks must be considered. In this study, we introduce a novel attack algorithm that relies on being able to compute sample means, sample covariances, and construct known linearly independent vectors on the data owner side. 

We show that these basic functionalities, which are available in several established FL frameworks, are sufficient to reconstruct privacy-protected data. Additionally, the attack algorithm is robust to defense strategies that involve adding random noise. We demonstrate the limitations of existing frameworks and propose potential defense strategies analyzing the implications of using differential privacy. The novel insights presented in this study will aid in the improvement of FL frameworks.

# Manuscript
The current draft of our paper can be found on [bioRxiv](https://www.biorxiv.org/content/10.1101/2022.10.09.511497v1).

## Federated Learning
![alt text](https://github.com/manuhuth/Data-Leakage-From-Covariances/blob/main/images/figure1.png?raw=true)
Federated Learning enables collaboration among multiple data owners who only share summary statistics, resulting in joint model training with larger sample sizes as for individual local training, all while preserving indiviudal data privacy. The increased sample sizes lead to stronger statistical power and therefore to a more rigorous falsification of statistical hypotheses. Federated Learning can produce parameter estimates with convergence properties identical to pooled estimates or even the same parameter estimates.



## Covariance-Based attack algorithms
![alt text](https://github.com/manuhuth/Data-Leakage-From-Covariances/blob/main/images/figure2.drawio.png?raw=true)
The algorithm assumes a distributed infrastructure with multiple servers, each hosting observations for different variables. The malicious client can focus on a specific variable on a specific server and retrieve the remaining data using three basic tools: a sample mean function, a sample covariance function, and an algorithm that generates linearly independent vectors. The algorithm involves evaluating the sample covariance to reconstruct inner vector products between the attacked variable and the linearly independent vectors, yielding a linear system of equations that can be solved to obtain the variable's data. The procedure can be repeated for each variable and server until all data is obtained.

## Applicability to large-scale data sets
The sample size determines the size of the system of equations, which is identical to the number of requests that must be sent to a specific server. The communication overhead for a request is constant, but the computation time will generally grow linearly with the sample size, as the dimensionality of the scalar product increases. Additionally, the computation time for solving the linear system from the equations grows cubically. To evaluate the scaling behavior in practice, subsets of the data set of different sizes were considered in our paper, and the wall time required to complete the attack was determined. The observed scaling was essentially linear, even for the largest data set considered, and the matrix inversion required only a small contribution to the overall time. This linear scaling behavior in the relevant regime, compared to the theoretically cubic scaling behavior, indicates that this attack is feasible in many real-world scenarios.


## Robust to noise perturbations
![alt text](https://github.com/manuhuth/Data-Leakage-From-Covariances/blob/main/images/figure4.png?raw=true)
The attack algorithm is robust to the addition of zero-mean noise to the means and covariances before returning them to the client. The noisy data estimate can be decomposed into the true data and a noise component, making it initially impossible for the malicious client to retrieve the original data. However, if the malicious client is given suitable communication and computational budgets, the client is able to run the algorithm R times, and the mean of the noisy data estimates converges to the true data. 

