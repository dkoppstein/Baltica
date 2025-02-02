source("load_sirv_data.R")
library(ComplexHeatmap)
library(RColorBrewer)

# df <- read.csv('/prj/Niels_Gehring/baltica_benchmark/1_1_2/sirv_input.csv')
# coordinates <- df$coordinate
# comparison <- df$comparison
# mat <- as.matrix(df[3:7])
# 
# methods <- colnames(mat)

# anno_barplot
mat <- as.matrix(df)
colnames(mat) <- gsub(x=colnames(mat), "orthogonal", 'SIRV') 
# rownames(mat) <- paste(coordinates, '_', comparison)
mat[mat > 0.95] <- 1
mat[mat < 0.95] <- 0
total <- colSums(mat, na.rm = T)
keep <- !is.na(mat[,5 ])
mat <- mat[keep, ]
mat[is.na(mat)] <- 0

# mat <- mat[rowSums(mat) >= 1, ]
comb_mat <- make_comb_mat(mat)

method <- str_extract(colnames(mat), str_c(methods, collapse = "|"))
color_list <- list(
  method = setNames(
    scales::brewer_pal(palette = "Set2")(length(methods)),
    methods
  )
)
comb_mat <- comb_mat[comb_degree(comb_mat) > 1]

# us <- UpSet(
#   comb_mat,
#   comb_order = order(rev(comb_degree(comb_mat))),
#   top_annotation = upset_top_annotation(comb_mat, add_numbers = T),
#   right_annotation = upset_right_annotation(comb_mat, add_numbers = T),
#   lwd = 0.8,
#   pt_size = unit(2, "mm"))

us <- UpSet(
  comb_mat,
  width = unit(100, "mm"),
  comb_order = order(rev(comb_degree(comb_mat))),
  top_annotation = columnAnnotation(
    inter = anno_barplot(
      comb_size(comb_mat), 
      gp = gpar(fill = "black"),
      height = unit(35, "mm"),
      add_numbers = T,
    ),
    annotation_name_side = 'left',
    show_annotation_name = TRUE,
    annotation_label = "Intersection\nsize"
  ),
  right_annotation = rowAnnotation(
    set_size = anno_barplot(
      set_size(comb_mat), 
      width = unit(50, "mm"),
      gp = gpar(fill = "black"),
      add_numbers = T,
      border = T
      ),
    total = anno_barplot(
      total, 
      width = unit(50, "mm"),
      gp = gpar(fill = "black"),
      add_numbers = T,
      border = T
      ),
    show_annotation_name = TRUE,
    annotation_label = c("Set size", "Total")),
  lwd = 0.8,
  pt_size = unit(2, "mm"))


pdf(
  "../sirv_benchmark/results/upset_calling_sirv.pdf",
  width = 10,
  height = 5,
  useDingbats = FALSE
)
draw(us)
dev.off()


# comb_mat2 <- make_comb_mat(mat[, 1:4])
# comb_mat2 <- comb_mat2[comb_degree(comb_mat2) > 1]
# us2 <- UpSet(
#   comb_mat2,
#   comb_order = order(rev(comb_degree(comb_mat2))),
#   top_annotation=upset_top_annotation(comb_mat2, add_numbers = T),
#   right_annotation = upset_right_annotation(
#     comb_mat2, add_numbers = T),
#   lwd = 0.8,
#   pt_size = unit(2, "mm"))
# 
# pdf(
#   "../sirv_benchmark/results/upset_calling_sirv_noortho.pdf",
#   width = 6,
#   height = 4,
#   useDingbats = FALSE
# )
# draw(us2)
# dev.off()
