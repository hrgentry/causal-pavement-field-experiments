# 使用 ggdag 生成论文因果图；tikzDevice 仅负责矢量输出及继承 LaTeX 字体。
# 参考 ASKurz, Statistical Rethinking 2e, Chapter 6, gg_fancy_dag。
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
script_path <- normalizePath(sub("^--file=", "", script_arg[[1]]), winslash = "/")
manuscript_dir <- dirname(script_path)
repo_dir <- normalizePath(file.path(manuscript_dir, "../../.."), winslash = "/")
local_library <- Sys.getenv("PMS_GGDAG_LIBRARY", file.path(repo_dir, "tmp/ggdag-r-library-4.5"))
.libPaths(c(local_library, .libPaths()))
latex_bin <- Sys.getenv("R_PDFLATEXCMD", Sys.which("pdflatex"))
if (!nzchar(latex_bin) || !file.exists(latex_bin)) stop("Set R_PDFLATEXCMD to an existing pdflatex executable")
options(tikzLatex = latex_bin, tikzDefaultEngine = "pdftex")
suppressPackageStartupMessages({library(ggdag); library(ggplot2); library(tikzDevice)})

font_setup <- c("\\usepackage[T1]{fontenc}\n",
                "\\usepackage[garamond,expert]{mathdesign}\n",
                "\\usepackage{fbb}\n",
                "\\renewcommand{\\bfdefault}{b}\n",
                "\\DeclareFontSeriesDefault[rm]{bf}{b}\n")
options(tikzMetricPackages = c(font_setup, "\\usetikzlibrary{calc}\n"),
        tikzLatexPackages = c("\\usepackage{tikz}\n", font_setup))
set.seed(20261015)


# 各图为作者提出的因果/统计假设，不把设计规定写成已验证的随机实施。
graph_records <- list()
make_dag <- function(id, coords, labels, edges, threats = character(), curves = numeric(), orange = character(), squares = character(), title = "") {
  edge_parts <- strsplit(edges, "->", fixed = TRUE)
  code <- paste0("dag { ", paste(vapply(edge_parts, function(z) paste(z, collapse = " -> "), ""), collapse = "; "), " }")
  dag <- dagitty::dagitty(code)
  dagitty::coordinates(dag) <- list(x = setNames(coords$x, coords$name), y = setNames(coords$y, coords$name))
  stopifnot(dagitty::isAcyclic(dag), !anyDuplicated(edges))
  td <- tidy_dagitty(dag)$data
  td$label <- unname(labels[td$name]); td$orange <- td$name %in% orange
  td$key <- paste(td$name, td$to, sep = "->")
  td$threat <- td$key %in% threats
  nd <- td[!duplicated(td$name), c("name", "x", "y", "label", "orange")]
  straight <- !is.na(td$to) & !td$key %in% names(curves)
  p <- ggplot(td, aes(x=x,y=y,xend=xend,yend=yend)) +
    geom_dag_edges_link(data=td[straight,], aes(edge_linetype=threat), edge_colour="grey30", edge_width=.4,
      start_cap=ggraph::circle(4.4,"mm"), end_cap=ggraph::circle(4.4,"mm"),
      arrow=grid::arrow(length=grid::unit(3,"pt"),type="closed"))
  for (edge in names(curves)) {
    p <- p + geom_dag_edges_arc(data=td[td$key == edge & !is.na(td$to),], aes(edge_linetype=threat),
      curvature=unname(curves[[edge]]), edge_colour="grey30", edge_width=.4,
      start_cap=ggraph::circle(4.4,"mm"),end_cap=ggraph::circle(4.4,"mm"),
      arrow=grid::arrow(length=grid::unit(3,"pt"),type="closed"))
  }
  p <- p + geom_dag_point(aes(colour=orange), alpha=.5,size=9.5,show.legend=FALSE) +
    geom_point(data=nd[nd$name %in% orange,],aes(x=x,y=y),inherit.aes=FALSE,
      colour="orange",shape=1,size=9.5,stroke=.8) +
    geom_point(data=nd[nd$name %in% squares,],aes(x=x,y=y),inherit.aes=FALSE,
      colour="grey30",shape=0,size=10.2,stroke=.5) +
    geom_dag_text(aes(label=label),colour="black",family="serif",size=3.1) +
    scale_colour_manual(values=c(`FALSE`="steelblue",`TRUE`="orange"),guide="none") +
    ggraph::scale_edge_linetype_manual(values=c(`FALSE`="solid",`TRUE`="dashed"),guide="none") +
    scale_x_continuous(NULL,breaks=NULL,expand=expansion(mult=.09)) +
    scale_y_continuous(NULL,breaks=NULL,expand=expansion(mult=.16)) +
    theme_dag() + theme(text=element_text(family="serif"),plot.margin=margin(9,12,9,12),
                       plot.title=element_text(size=10,hjust=0)) + labs(title=title)
  graph_records[[id]] <<- list(nodes=nd,edges=sort(edges),edge_count=length(edges),acyclic=TRUE,
                             sensitivity_edges=threats,dagitty=as.character(dag))
  p
}
coords <- function(n,x,y) tibble::tibble(name=n,x=x,y=y)

# SPS-10: 生产温度、压实状态与其他技术路径；不假设完全中介。
e10 <- c("L->A","L->T","L->V","L->Y","U->A","U->Y",
         "A->T","A->V","A->Y","T->V","T->Y","V->Y")
p10 <- make_dag("sps10-mechanism",
  coords(c("A","T","V","Y","L","U"),c(0,3,6,9,4.5,4.5),c(0,1.6,1.6,0,3.8,-2)),
  c(A="$A_{10}$",T="$T$",V="$V$",Y="$Y_t$",L="$L_0$",U="$U$"),e10,
  threats=c("L->A","U->A","U->Y"),orange="U",
  title="A. SPS-10: technology, temperature and compaction")

# SPS-5: 三个共同干预分量并行；不添加P、M、H之间的假顺序。
e5 <- c("L->P","L->M","L->H","L->S","L->Y","U->P","U->M","U->H","U->Y",
        "P->S","P->Y","M->Y","H->Y","S->Y")
p5 <- make_dag("sps5-mechanism",
  coords(c("P","M","H","S","Y","L","U"),c(0,0,0,4,8,4,4),c(1.8,0,-1.8,2,0,4.4,-3.6)),
  c(P="$P$",M="$M$",H="$H$",S="$S$",Y="$Y_t$",L="$L_0$",U="$U$"),e5,
  threats=c("L->P","L->M","L->H","U->P","U->M","U->H","U->Y"),orange="U",
  title="A. SPS-5: preparation, material and thickness")

# 共同随访子图。A在SPS-5代表对(P,M,H)的共同干预，非另一独立处理。
ef <- c("L->D","L->Y1","U->D","U->Y1","A->Y0","A->D","A->Y1",
        "Y0->D","Y0->Y1","Y0->R","D->Y1","D->R","E->Y0","E->D","E->Y1",
        "Y1->Yr","Y1->R","Q->Yr","Q->R")
pf <- make_dag("common-followup",
  coords(c("A","Y0","D","Y1","Yr","R","Q","E","L","U"),
         c(0,3,3,6,8,10,10,6,0,0),c(0,0,-2,0,0,-2,2.5,2.5,2.5,-2)),
  c(A="$A$",Y0="$Y_t$",D="$D_t$",Y1="$Y_{t+1}$",Yr="$Y_{\\mathrm{rec}}$",R="$R{=}1$",
    Q="$Q$",E="$E_t$",L="$L_0$",U="$U$"),ef,
  threats=c("U->D","U->Y1","Y1->R"),curves=c("A->Y1"=.6),orange="U",squares="R",
  title="B. Shared follow-up and recording assumptions")

write_pair <- function(file, top) {
  tikz(file=file,width=5.4,height=5.5,pointsize=10,standAlone=FALSE,sanitize=FALSE,
       symbolicColors=FALSE,timestamp=FALSE)
  grid::grid.newpage()
  print(top,vp=grid::viewport(x=.5,y=.75,width=1,height=.5),newpage=FALSE)
  print(pf,vp=grid::viewport(x=.5,y=.25,width=1,height=.5),newpage=FALSE)
  invisible(dev.off())
}
write_pair(file.path(manuscript_dir,"figures/dag-sps10.tex"),p10)
write_pair(file.path(manuscript_dir,"figures/dag-sps5.tex"),p5)

# 图2是统计依赖图，按冻结模型的对数正态参数化绘制，不赋予因果含义。
eb <- c("K->theta","K->b","K->s","K->sigma","theta->eta","b->eta","s->eta","X->eta",
        "eta->mu","sigma->mu","mu->Y","sigma->Y")
pb <- make_dag("bayesian-structure",
  coords(c("K","theta","b","s","sigma","X","eta","mu","Y"),
         c(4.5,0,3,6,9,0,4.5,4.5,4.5),c(4,2,2,2,2,0,0,-2,-4)),
  c(K="$K$",theta="$\\theta$",b="$b_p$",s="$s_s$",sigma="$\\sigma_y$",X="$X$",
    eta="$\\eta^*$",mu="$\\mu_{\\log}$",Y="$Y$"),eb,
  curves=c("sigma->Y"=.45),title="A. M0 statistical dependence (not a causal DAG)")
workflow <- ggplot() +
  annotate("text",x=0,y=3,label="B. Computation for each fit",hjust=0,family="serif",size=3.5) +
  annotate("text",x=0,y=2,label="Frozen panel $\\longrightarrow$ four NUTS chains",hjust=0,family="serif",size=3.4) +
  annotate("text",x=0,y=1,label="Per chain: 1,000 warmup + 2,000 retained iterations",hjust=0,family="serif",size=3.4) +
  annotate("text",x=0,y=0,label="$\\longrightarrow$ diagnostics and 8,000 retained draws",hjust=0,family="serif",size=3.4) +
  xlim(0,10)+ylim(-.5,3.5)+theme_void()
tikz(file=file.path(manuscript_dir,"figures/bayesian-structure.tex"),width=5.4,height=4.5,pointsize=10,
     standAlone=FALSE,sanitize=FALSE,symbolicColors=FALSE,timestamp=FALSE)
grid::grid.newpage()
print(pb,vp=grid::viewport(x=.5,y=.66,width=1,height=.68),newpage=FALSE)
print(workflow,vp=grid::viewport(x=.5,y=.14,width=.95,height=.28),newpage=FALSE)
invisible(dev.off())
versions <- vapply(c("ggdag","ggplot2","dagitty","ggraph","tikzDevice"),
                   function(x) as.character(packageVersion(x)),character(1))
metadata <- list(renderer="ggdag + ggplot2, exported by tikzDevice",
  reference="https://github.com/ASKurz/Statistical_Rethinking_with_brms_ggplot2_and_the_tidyverse_2_ed/blob/master/06.qmd",
  reference_chapter_sha256="2e9debf8065bd13a2fc32ec9265c0309a7e2f27cfc761c3af6efbc0c10bb6bf5",
  R_version=as.character(getRversion()),packages=as.list(versions),
  fonts="fbb text; Garamond MathDesign math, inherited in LaTeX",
  scope="Distinct as-implemented case mechanisms plus explicitly shared follow-up subgraph; statistical hierarchy is not causal",
  graphs=graph_records)
jsonlite::write_json(metadata,file.path(manuscript_dir,"causal-evidence/ggdag-graphs.json"),
                    auto_unbox=TRUE,pretty=TRUE,dataframe="rows")
writeLines(capture.output(sessionInfo()),file.path(manuscript_dir,"causal-evidence/ggdag-session.txt"))
cat("Rendered case-specific mechanisms, shared follow-up and M0 statistical graph.\n")
