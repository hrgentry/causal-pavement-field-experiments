# 冻结记录及既有后验的图；不运行Stan、不生成新的后验抽样。
args <- commandArgs(trailingOnly=FALSE)
script <- normalizePath(sub('^--file=', '', grep('^--file=', args, value=TRUE)[1]), winslash='/')
here <- dirname(script)
repo <- normalizePath(file.path(here,'../../..'), winslash='/')
.libPaths(c(file.path(repo,'tmp/ggdag-r-library-4.5'),.libPaths()))
suppressPackageStartupMessages({library(ggplot2);library(tikzDevice);library(jsonlite);library(digest)})
latex <- Sys.getenv('R_PDFLATEXCMD', Sys.which('pdflatex'))
stopifnot(nzchar(latex),file.exists(latex))
fonts <- c('\\usepackage[T1]{fontenc}\n','\\usepackage[garamond,expert]{mathdesign}\n','\\usepackage{fbb}\n',
           '\\renewcommand{\\bfdefault}{b}\n','\\DeclareFontSeriesDefault[rm]{bf}{b}\n')
options(tikzLatex=latex,tikzDefaultEngine='pdftex',tikzMetricPackages=c(fonts,'\\usetikzlibrary{calc}\n'),
        tikzLatexPackages=c('\\usepackage{tikz}\n',fonts,'\\usetikzlibrary{calc}\n'))
out <- file.path(repo,'studies/01-wma-long-term-factors/analysis/outputs/astra-critic-revision-v2')
sha <- function(p) digest(file=p,algo='sha256',serialize=FALSE)
report <- fromJSON(file.path(out,'analysis-report.json'),simplifyVector=FALSE)
stopifnot(identical(report$status,'PASS'),report$new_native_fits==0,report$new_draw_generation==0)
input_hashes <- list()
read_checked <- function(name) {
  p <- file.path(out,name)
  stopifnot(identical(sha(p),report$outputs[[name]]))
  input_hashes[[name]] <<- sha(p)
  header <- names(read.csv(p,nrows=0,check.names=FALSE))
  classes <- setNames(rep(NA_character_,length(header)),header)
  classes[intersect(header,c('section','minimum_section','intensive_section'))] <- 'character'
  read.csv(p,check.names=FALSE,colClasses=classes)
}
theme_case <- function() theme_classic(base_size=10,base_family='serif')+
  theme(axis.line=element_line(linewidth=.25,colour='grey50'),
        axis.ticks=element_line(linewidth=.25,colour='grey50'),
        strip.background=element_blank(),strip.text=element_text(size=9.5),
        panel.spacing=grid::unit(12,'pt'),legend.position='none',
        plot.margin=margin(7,12,6,8),axis.title=element_text(size=10),axis.text=element_text(size=9))
outputs <- list()
save <- function(name,p,w,h) {
  target <- file.path(here,'figures',paste0(name,'.tex'))
  tikz(target,standAlone=FALSE,width=w,height=h,pointsize=10)
  print(p);dev.off()
  preview <- file.path(here,'figures',paste0(name,'.png'))
  ggsave(preview,p,width=w,height=h,units='in',dpi=180,bg='white')
  outputs[[name]] <<- list(tex_sha256=sha(target),preview_sha256=sha(preview),width_in=w,height_in=h,pointsize=10)
}
origin <- as.Date('1989-09-12')
pairs <- read_checked('manitoba-observed-pairs52.csv')
stopifnot(nrow(pairs)==52,length(unique(pairs$campaign))==13)
pairs$age <- (as.numeric(as.Date(pairs$minimum_date)-origin)+as.numeric(as.Date(pairs$intensive_date)-origin))/2/365.25
pair_keys <- unique(pairs[,c('pair_label','minimum_section','intensive_section')])
pair_keys <- pair_keys[order(pair_keys$pair_label),]
pair_keys$display <- paste0(tools::toTitleCase(pair_keys$pair_label),'\n',pair_keys$intensive_section,' - ',pair_keys$minimum_section)
pairs$display <- factor(pair_keys$display[match(pairs$pair_label,pair_keys$pair_label)],levels=pair_keys$display)
events <- read_checked('manitoba-common-events.csv')
events$age <- as.numeric(as.Date(events$date)-origin)/365.25
events <- events[events$age >= min(pairs$age) & events$age <= max(pairs$age),]
p <- ggplot(pairs,aes(age,difference_mm))+
  geom_hline(yintercept=0,colour='grey55',linewidth=.3)+
  geom_vline(data=events,aes(xintercept=age),inherit.aes=FALSE,colour='grey75',linetype='dotted',linewidth=.28)+
  geom_line(colour='#2b5d7d',linewidth=.45)+geom_point(colour='#2b5d7d',size=1.2)+
  facet_wrap(~display,ncol=2)+
  scale_x_continuous(breaks=c(5,10,15,20,25),expand=expansion(mult=c(.035,.045)))+
  scale_y_continuous(breaks=c(-1,0,2,4,6,8),expand=expansion(mult=c(.07,.06)))+
  labs(x='Age from travel-lane opening (years)',y='Recorded rut depth difference (mm)')+theme_case()
save('ar68-manitoba-observed-pairs',p,5.32,3.85)

ppc <- read_checked('manitoba-linked-current-ppc104.csv')
stopifnot(nrow(ppc)==104,length(unique(ppc$section))==8)
ppc$display <- paste0(ppc$section,'\n',tools::toTitleCase(ppc$preparation),', ',ppc$material,', ',ppc$thickness_label)
ppc$display <- factor(ppc$display,levels=unique(ppc$display))
ppc <- ppc[order(ppc$section,ppc$age),]
p <- ggplot(ppc,aes(age,observed_mm))+
  geom_linerange(aes(ymin=ppc_low_mm,ymax=ppc_high_mm),colour='grey76',linewidth=.4)+
  geom_line(aes(y=ppc_median_mm),colour='#2b5d7d',linewidth=.45)+
  geom_point(colour='grey10',size=1.05)+facet_wrap(~display,ncol=2)+
  scale_x_continuous(breaks=c(5,15,25),expand=expansion(mult=c(.035,.045)))+
  scale_y_continuous(limits=c(0,NA),expand=expansion(mult=c(0,.045)))+
  labs(x='Age from travel-lane opening (years)',y='Recorded rut depth (mm)')+theme_case()
save('ar68-manitoba-linked-current-ppc',p,5.32,5.85)
receipt <- list(schema='AR68_R_GGPLOT_DISPLAY_V2',status='PASS_INPUT_IDENTITY_AND_RENDER',
                generator_sha256=sha(script),analysis_report_sha256=sha(file.path(out,'analysis-report.json')),
                inputs=input_hashes,outputs=outputs,new_fits=0,new_posterior_draws=0,
                common_event_dates_displayed=as.character(events$date),
                interpretation='Observed pair differences and current linked-reference in-sample pointwise PPC only; no causal treatment effect or future calibration claim.')
write_json(receipt,file.path(here,'figures','ar68-render-receipt.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('Rendered two ggplot2/TikZ figures from frozen data and existing linked-reference draws.\n')
