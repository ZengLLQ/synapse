# LoRA: Low-Rank Adaptation of Large Language Models

## Abstract
An important paradigm of natural language processing consists of large-scale pre-training on general domain data and adaptation to specific tasks or domains. As we pre-train larger models, full fine-tuning, which retrains all model parameters, becomes less feasible. Using GPT-3 175B as an example, deploying independent instances of fine-tuned models, each with 175B parameters, is prohibitive. We propose Low-Rank Adaptation, or LoRA, which freezes the pre-trained model weights and injects trainable rank decomposition matrices into each layer of the Transformer architecture, greatly reducing the number of trainable parameters for downstream tasks.

## Problem Formulation and Method
We hypothesize that the changes in weights during model adaptation have a low intrinsic dimension. For a pre-trained weight matrix $W_0 \in \mathbb{R}^{d \times k}$, we constrain its update by representing the latter with a low-rank decomposition:
$$W_0 + \Delta W = W_0 + B A$$
where $B \in \mathbb{R}^{d \times r}$, $A \in \mathbb{R}^{r \times k}$, and the rank $r \ll \min(d, k)$. During training, $W_0$ is frozen and does not receive gradient updates, while $A$ and $B$ contain trainable parameters.

## Empirical Evaluation
Compared to full fine-tuning of GPT-3 175B, LoRA can reduce the number of trainable parameters by 10,000 times and the GPU memory requirement by 3 times. LoRA performs on par or better than fine-tuning in model quality on RoBERTa, DeBERTa, GPT-2, and GPT-3, despite having fewer trainable parameters, a higher training throughput, and no additional inference latency.
