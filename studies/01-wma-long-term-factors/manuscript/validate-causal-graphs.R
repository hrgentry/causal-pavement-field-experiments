# 对图中识别威胁作符号核查；这些结果只针对所声明的图，不验证现实假设。
args <- commandArgs(trailingOnly=FALSE)
script <- normalizePath(sub("^--file=","",grep("^--file=",args,value=TRUE)[[1]]),winslash="/")
p <- dirname(script); root <- normalizePath(file.path(p,"../../.."),winslash="/")
.libPaths(c(Sys.getenv("PMS_GGDAG_LIBRARY",file.path(root,"tmp/ggdag-r-library-4.5")),.libPaths()))
library(dagitty)
records <- jsonlite::fromJSON(file.path(p,"causal-evidence/ggdag-graphs.json"),simplifyVector=FALSE)$graphs
results <- list()
for (name in c("sps10-mechanism","sps5-mechanism")) {
  item <- records[[name]]
  g <- dagitty(item$dagitty)
  exposures(g) <- if (name == "sps10-mechanism") "A" else c("P","M","H")
  outcomes(g) <- "Y"; latents(g) <- "U"
  a <- adjustmentSets(g,type="minimal",effect="total")
  stopifnot(isAcyclic(g),length(a)==0)
  # 仅删U发出的候选路径；保留基线共同原因，检查理想化约化图。
  reduced <- unlist(item$edges); reduced <- reduced[!grepl("^U->",reduced)]
  r <- dagitty(paste0("dag {",paste(gsub("->"," -> ",reduced,fixed=TRUE),collapse="; "),"}"))
  exposures(r) <- exposures(g); outcomes(r) <- "Y"
  b <- adjustmentSets(r,type="minimal",effect="total")
  bs <- lapply(b,as.character)
  stopifnot(length(bs)==1,identical(sort(bs[[1]]),"L"))
  if (name=="sps5-mechanism") {
    stopifnot(!"M" %in% descendants(g,"P"),!"H" %in% descendants(g,"P"),
              "S" %in% descendants(g,"P"))
  } else stopifnot(all(c("T","V") %in% descendants(g,"A")))
  results[[name]] <- list(exposures=exposures(g),outcome="Y",latent="U",
    minimal_measured_sets_with_U=as.list(a),minimal_sets_after_removing_U_paths=bs,
    scope="Mechanism panel only. The reduced graph is hypothetical; observation/management identification is additional.")
}
f <- unlist(records[["common-followup"]]$edges)
stopifnot(all(c("A->Y1","E->Y0","Y0->D","D->Y1","Y1->Yr","Q->Yr","Q->R","Y1->R") %in% f),
          !"Q->Y1" %in% f)
results$common_followup <- list(physical_record_separation=TRUE,direct_later_treatment_path=TRUE,
                               possible_outcome_dependent_selection=TRUE)
jsonlite::write_json(list(status="pass",dagitty_version=as.character(packageVersion("dagitty")),
                         checks=results),file.path(p,"causal-evidence/dag-identification-check.json"),
                    auto_unbox=TRUE,pretty=TRUE)
cat("Graph-specific identification checks passed. No measured adjustment set with U; reduced mechanism graphs require L0.\n")
