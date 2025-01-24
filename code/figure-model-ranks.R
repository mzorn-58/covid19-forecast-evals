library(tidyverse)
library(covidHubUtils)
library(ggridges)
library(viridis)
library(cowplot)

theme_set(theme_bw())
data("hub_locations")

inc_scores <- read_csv("paper-inputs/inc-scores.csv") %>%
  filter(!(location_name %in%  c("American Samoa", "Northern Mariana Islands")), 
    target %in% paste(1:4, "wk ahead inc death")) %>%
  mutate(id = paste(target_end_date_1wk_ahead, target, location_name)) 


inc_scores_overall <- inc_scores %>%
  filter(include_overall == "TRUE") %>%
  group_by(target_end_date_1wk_ahead, target, location_name) %>%
  mutate(n_models = n()) %>%
  ##filter(n_models >= 15) %>%
  arrange(wis) %>%
  mutate(model_rank = row_number(), rank_percentile = model_rank/n_models) %>%
  arrange(-wis) %>%
  mutate(rev_rank = (row_number()-1)/(n_models-1)) %>%
  ungroup() %>%
  mutate(model = reorder(model, rev_rank, FUN=function(x) quantile(x, probs=0.25, na.rm=TRUE)))

# number of unique opportunities for a prediction
inc_scores_overall %>%
  group_by(target_end_date_1wk_ahead, location_name, target) %>%
  summarize(n()) %>%
  nrow()

## number of unique opportunities for a prediction by model
# inc_scores %>%
#   group_by(model) %>%
#   summarize(n()) 

# table(inc_scores$n_models)

## average rank
inc_scores_overall %>%
  group_by(model) %>%
  summarize(average_rank = mean(model_rank), total_n = n(), 
            n_top_rank = sum(model_rank==1), pct_top = n_top_rank/total_n*100) %>%
  print(n=Inf) 

## average rank
average_rank_percent <- inc_scores_overall %>%
  group_by(model) %>%
  summarize(average_rank = mean(rev_rank), total_n = n(), 
            n_top50 = sum(rev_rank> 0.5) , pct_top50 = n_top50/total_n*100) %>%
  print(n=Inf) %>% arrange(-pct_top50)

# ggplot(inc_scores, aes(y=id, x=model, fill=model_rank)) +
#   geom_tile() +
# #  facet_grid(location_name + target_end_date_1wk_ahead + target ~.) +
#   scale_fill_gradient(na.value="red") +
#   scale_y_discrete(labels=element_blank()) +
#   theme(
#     axis.text.x = element_text(angle = 45, hjust = 1, size = 10),
#     axis.title.y=element_blank(),
#     axis.text.y=element_blank(),
#     axis.ticks.y=element_blank())

# p1 <- ggplot(inc_scores, aes(x=model, fill=factor(model_rank))) +
#   # geom_bar(position="fill") + ## for percentages
#   geom_bar() +
#   scale_y_continuous(expand = expansion(mult=c(0, 0.05))) +
#   scale_fill_viridis(discrete=TRUE, direction = -1, name="model rank") +
#   theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
#   xlab(NULL)
#   

# ggplot(inc_scores, aes(y=model, x=rank_percentile)) +
#   geom_boxplot()

# inc_scores_sum <- inc_scores_overall %>%
#   group_by(model) %>%
#   summarize(mean_rp = mean(rev_rank),
#     q25_rp = quantile(rev_rank, probs=0.25),
#     median_rp = median(rev_rank),
#     q75_rp = quantile(rev_rank, probs=0.75))

# ggplot(inc_scores, aes(y=model, x=rank_percentile, height = ..density..)) +
#   geom_density_ridges(scale = 1, stat = "density", trim = TRUE) + 
#   scale_y_discrete(expand = c(0, 0)) +     # will generally have to set the `expand` option
#   scale_x_continuous(expand = c(0, 0), limits=c(0,1)) +   # for both axes to remove unneeded padding
#   coord_cartesian(clip = "off") + # to avoid clipping of the very top of the top ridgeline
#   theme_ridges() +
#   geom_vline(xintercept=1/17)
# 
# ggplot(inc_scores, aes(y=model, x=rank_percentile, height = ..density..)) +
#   geom_density_ridges(stat = "binline", binwidth=.05, draw_baseline = F) +
#   scale_y_discrete(expand = c(0, 0)) +     # will generally have to set the `expand` option
#   scale_x_continuous(expand = c(0, 0), limits=c(0,1)) +   # for both axes to remove unneeded padding
#   scale_fill_viridis_d(direction = -1, name="model rank") +
#   coord_cartesian(clip = "off") + # to avoid clipping of the very top of the top ridgeline
#   theme_ridges()
# 
# ggplot(inc_scores, aes(y=model, x=rank_percentile, fill = stat(x))) +
#   geom_density_ridges_gradient(scale = 1) + 
#   #geom_ridgeline_gradient() +
#   scale_y_discrete(expand = c(0, 0)) +     # will generally have to set the `expand` option
#   scale_x_continuous(expand = c(0, 0), limits=c(0,1)) +   # for both axes to remove unneeded padding
#   scale_fill_viridis_c(direction = -1, name="model rank") +
#   coord_cartesian(clip = "off") + # to avoid clipping of the very top of the top ridgeline
#   theme_ridges()


p2 <- ggplot(inc_scores_overall, aes(y=model, x=rev_rank, fill = factor(stat(quantile)))) +
  stat_density_ridges(
    geom = "density_ridges_gradient", calc_ecdf = TRUE,
    quantiles = 4, quantile_lines = TRUE
  ) +
  scale_fill_viridis_d(name = "Quartiles") +
  scale_x_continuous(name="standardized rank", 
    #expand=expansion(add=c(2, 1)/max(inc_scores$n_models)), 
    limits=c(0,1)) +   # for both axes to remove unneeded padding +
scale_y_discrete(labels=c("IHME-CurveFit" = "IHME-SEIR"))
  

pdf(file = "figures/fig-model-ranks.pdf", width=8, height=5)
print(p2)
dev.off()

jpeg(file = "figures/fig-model-ranks.jpg", width=8, height=5, units="in", res=300)
print(p2)
dev.off()



## sensitivity analysis showing what we might expect if scores were uniform
model_obs <- inc_scores %>%
  group_by(model) %>%
  summarize(nobs=n()) %>%
  pull(nobs)

forecasters <- rep(paste0("f_", letters[1:length(model_obs)]), 
  times=model_obs)

## with same number of obs, different unit structure
# fake_scores <- tibble(model = forecasters,
#   score = runif(length(forecasters))) %>%
#   group_by(model) %>%
#   mutate(obs_num = row_number()) %>%
#   group_by(obs_num) %>%
#   mutate(rank = rank(-score)-1, nobs = n()-1, rp = rank/nobs)

## replacing original scores
fake_scores <- inc_scores %>%
  mutate(wis = runif(nrow(inc_scores))) %>%
  group_by(model) %>%
  mutate(obs_num = row_number()) %>%
  group_by(obs_num) %>%
  mutate(rank = rank(-wis)-1, nobs = n()-1, rp = rank/nobs)

ggplot(fake_scores, aes(y=model, x=rp, fill = factor(stat(quantile)))) +
  stat_density_ridges(
    geom = "density_ridges_gradient", calc_ecdf = TRUE,
    quantiles = 4, quantile_lines = TRUE,
    scale=1
  ) +
  scale_fill_viridis_d(name = "Quartiles", direction=-1) +
  scale_x_continuous(name="rank percentile", 
    limits=c(0,1))    # for both axes to remove unneeded padding


##Model Ranking by Phases of the Pandemic


inc_scores_phase <- inc_scores %>%
  filter(include_phases == "TRUE") %>%
  group_by(target_end_date_1wk_ahead, target, location_name, seasonal_phase) %>%
  mutate(n_models = n()) %>%
  arrange(wis) %>%
  mutate(model_rank = row_number(), rank_percentile = model_rank/n_models) %>%
  arrange(-wis) %>%
  mutate(rev_rank = (row_number()-1)/(n_models-1)) %>%
  ungroup() %>%
  mutate(model = reorder(model, rev_rank, FUN=function(x) quantile(x, probs=0.25, na.rm=TRUE)))


p2_phase_1 <- ggplot(inc_scores_phase %>% filter(seasonal_phase %in% c("spring","summer")),aes(y= model, x=rev_rank, fill = factor(stat(quantile)))) +
  facet_wrap(~ seasonal_phase) +
  stat_density_ridges(
    geom = "density_ridges_gradient", calc_ecdf = TRUE,
    quantiles = 4, quantile_lines = TRUE) + 
#scale_fill_viridis_d(name = "Quartiles") +
  scale_x_continuous(name="standardized rank", 
                     limits=c(0,1)) +   # for both axes to remove unneeded padding +
  scale_fill_manual(name = " ", values = c("#381648", "#5FB580", "#FAE955", "#406789")) +
  scale_y_discrete(labels=c("IHME-CurveFit" = "IHME-SEIR"), drop = FALSE) +
  theme(legend.position = "none",
        axis.text.y = element_text(size = 12),
        axis.title.y = element_text(size =12),
        strip.text = element_text(size = 14),
        axis.title.x = element_text(hjust = 1)
  )

p2_phase_2 <- ggplot(inc_scores_phase %>% filter(seasonal_phase %in% c("winter", "delta")),aes(y= model, x=rev_rank, fill = factor(stat(quantile)))) +
  facet_wrap(~ factor(seasonal_phase, levels = c("winter", "delta")))  +
  stat_density_ridges(
    geom = "density_ridges_gradient", calc_ecdf = TRUE,
    quantiles = 4, quantile_lines = TRUE) + 
  scale_fill_manual(name = "Quantiles", values = c("#381648", "#406789", "#5FB580", "#FAE955")) +
  scale_x_continuous(name=" ", 
                     limits=c(0,1)) +   # for both axes to remove unneeded padding +
  scale_y_discrete(labels=c("IHME-CurveFit" = "IHME-SEIR"), drop = FALSE) +
  theme(axis.text.y = element_blank(),
        axis.title.y = element_blank(),
        axis.ticks.y = element_blank(),
        strip.text.x = element_text(size = 15))

jpeg(file = "figures/model_ranks_phase.jpg", width=14, height=11, units="in", res=300)
plot_grid(p2_phase_1, p2_phase_2,  ncol = 2, rel_widths = c(1,1))
dev.off()

pdf(file = "figures/model_ranks_phase.pdf", width=8, height=11)
plot_grid( p2_phase_1, p2_phase_2, rel_widths = c(2,1))
dev.off()

# 
# 
# phase_test <- ggplot(inc_scores_phase,aes(y= model, x=rev_rank, fill = factor(stat(quantile)))) +
#   facet_wrap(~ seasonal_phase) +
#   stat_density_ridges(
#     geom = "density_ridges_gradient", calc_ecdf = TRUE,
#     quantiles = 4, quantile_lines = TRUE) + 
#   #scale_fill_viridis_d(name = "Quartiles") +
#   scale_x_continuous(name="standardized rank", 
#                      limits=c(0,1)) +   # for both axes to remove unneeded padding +
#   scale_fill_manual(name = " ", values = c("#381648", "#5FB580", "#FAE955", "#406789")) +
#   scale_y_discrete(labels=c("IHME-CurveFit" = "IHME-SEIR"), drop = FALSE) +
#   theme(legend.position = "none",
#         axis.text.y = element_text(size = 12),
#         axis.title.y = element_text(size =12),
#         strip.text = element_text(size = 14),
#         axis.title.x = element_text(hjust = 1))
#   