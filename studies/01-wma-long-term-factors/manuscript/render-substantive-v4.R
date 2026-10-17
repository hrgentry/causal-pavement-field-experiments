# Checked v4 tables -> ggplot2/TikZ; no model fitting or source-data mutation.
args <- commandArgs(trailingOnly=FALSE)
script <- normalizePath(sub('^--file=', '', grep('^--file=', args, value=TRUE)[1]), winslash='/')
here <- dirname(script)
repo <- normalizePath(file.path(here,'../../..'),winslash='/')
.libPaths(c(file.path(repo,'tmp/ggdag-r-library-4.5'),.libPaths()))
suppressPackageStartupMessages({library(ggplot2);library(tikzDevice);library(jsonlite);library(digest)})
latex <- Sys.getenv('R_PDFLATEXCMD',Sys.which('pdflatex'))
stopifnot(nzchar(latex),file.exists(latex))
fonts <- c('\\usepackage[T1]{fontenc}\n','\\usepackage[garamond,expert]{mathdesign}\n','\\usepackage{fbb}\n',
           '\\renewcommand{\\bfdefault}{b}\n','\\DeclareFontSeriesDefault[rm]{bf}{b}\n')
options(tikzLatex=latex,tikzDefaultEngine='pdftex',tikzMetricPackages=c(fonts,'\\usetikzlibrary{calc}\n'),
        tikzLatexPackages=c('\\usepackage{tikz}\n',fonts,'\\usetikzlibrary{calc}\n'))
out <- file.path(repo,'studies/01-wma-long-term-factors/analysis/outputs/substantive-revision-v4')
sha <- function(p) digest(file=p,algo='sha256',serialize=FALSE)
inputs <- list();outputs <- list()
checked <- function(name) {
  path <- file.path(out,name);inputs[[name]] <<- sha(path)
  read.csv(path,check.names=FALSE,stringsAsFactors=FALSE)
}
theme_case <- function() theme_classic(base_size=10,base_family='serif')+
  theme(axis.line=element_line(linewidth=.25,colour='grey55'),axis.ticks=element_line(linewidth=.25,colour='grey55'),
        strip.background=element_blank(),strip.text=element_text(size=9.5),legend.position='none',
        panel.spacing=grid::unit(12,'pt'),plot.margin=margin(6,9,6,6),
        axis.text=element_text(size=9),axis.title=element_text(size=10))
save_plot <- function(name,p,w,h) {
  tex <- file.path(here,'figures',paste0(name,'.tex'))
  tikz(tex,standAlone=FALSE,width=w,height=h,pointsize=10);print(p);dev.off()
  png <- file.path(here,'figures',paste0(name,'.png'))
  ggsave(png,p,width=w,height=h,units='in',dpi=180,bg='white')
  outputs[[name]] <<- list(tex_sha256=sha(tex),preview_sha256=sha(png),width_in=w,height_in=h)
}
s <- checked('sps10-targets.csv')
s <- s[s$model %in% c('iid-reference','rho-beta22') & s$target!='same-date-rho',]
s$contrast <- factor(s$contrast,levels=c('F-H','C-H'))
stopifnot(nrow(s)==16)
target <- c('new6'='New-6','new4'='New-4','existing4'='Existing-4','expected_bracket_operator'='E(WY)')
s$display <- paste(target[s$target],ifelse(s$model=='rho-beta22','estimated','independent'))
lev <- as.vector(rbind(paste(target,'independent'),paste(target,'estimated')))
s$display <- factor(s$display,levels=rev(lev))
p <- ggplot(s,aes(median,display))+
  geom_vline(xintercept=0,colour='grey65',linewidth=.28)+
  geom_linerange(aes(xmin=lower,xmax=upper,colour=model),orientation='y',linewidth=.55)+
  geom_point(aes(colour=model,shape=model),size=1.6)+facet_wrap(~contrast,nrow=1)+
  scale_colour_manual(values=c('iid-reference'='grey50','rho-beta22'='#2b5d7d'))+
  scale_shape_manual(values=c('iid-reference'=1,'rho-beta22'=16))+
  scale_x_continuous(breaks=c(-.6,-.3,0,.3,.6),expand=expansion(mult=.07))+
  labs(x='Model mean difference (mm)',y=NULL)+theme_case()+
  theme(panel.spacing=grid::unit(16,'pt'),plot.margin=margin(6,9,6,22))
save_plot('v4-sps10-targets',p,5.32,3.40)

mb <- checked('manitoba-held-pair-validation.csv')
mb <- mb[mb$model %in% c('linear-stationary','linear-event'),]
stopifnot(nrow(mb)==104)
mb$year <- as.integer(sub('\\|D','',mb$campaign))
mb$x <- mb$year+ifelse(mb$model=='linear-event',.14,-.14)
labels <- c('recycled-lower'='Recycled lower: 0509 - 0502','recycled-upper'='Recycled upper: 0508 - 0503',
            'virgin-lower'='Virgin lower: 0506 - 0505','virgin-upper'='Virgin upper: 0507 - 0504')
mb$display <- factor(labels[mb$pair],levels=unname(labels))
obs <- mb[mb$model=='linear-stationary',]
p <- ggplot(mb,aes(x,median,colour=model,linetype=model))+
  geom_hline(yintercept=0,colour='grey60',linewidth=.27)+
  geom_linerange(aes(ymin=lower,ymax=upper),linewidth=.35)+
  geom_point(aes(shape=model),size=1.1)+
  geom_point(data=obs,aes(x=year,y=observed_mm),inherit.aes=FALSE,colour='black',size=1.1)+
  facet_wrap(~display,ncol=2)+
  scale_colour_manual(values=c('linear-stationary'='grey55','linear-event'='#2b5d7d'))+
  scale_linetype_manual(values=c('linear-stationary'='solid','linear-event'='dashed'))+
  scale_shape_manual(values=c('linear-stationary'=1,'linear-event'=2))+
  scale_x_continuous(breaks=c(1995,2005,2015),expand=expansion(mult=.04))+
  labs(x='Held campaign year',y='Rut depth difference (mm)')+theme_case()
save_plot('v4-mb-held-pairs',p,5.32,4.00)

trace <- checked('trace-data.csv')
trace$chain <- factor(trace$chain)
cols <- c('1'='black','2'='grey40','3'='grey65','4'='#2b5d7d')
lines <- c('1'='solid','2'='dashed','3'='dotdash','4'='dotted')
save_trace <- function(case,name) {
  d <- trace[trace$case==case,];d$quantity <- factor(d$quantity,levels=unique(d$quantity))
  d$bin <- pmin(20L,pmax(1L,as.integer(floor((d$pooled_rank-.5)/400)+1)))
  counts <- aggregate(iteration~quantity+chain+bin,data=d,FUN=length)
  names(counts)[names(counts)=='iteration'] <- 'count'
  bins <- expand.grid(quantity=levels(d$quantity),chain=levels(d$chain),bin=seq_len(20),stringsAsFactors=FALSE)
  bins <- merge(bins,counts,by=c('quantity','chain','bin'),all.x=TRUE)
  bins$count[is.na(bins$count)] <- 0L
  bins$center <- .5+(bins$bin-.5)*400
  bins$quantity <- factor(bins$quantity,levels=levels(d$quantity));bins$chain <- factor(bins$chain,levels=levels(d$chain))
  stopifnot(all(aggregate(count~quantity+chain,data=bins,FUN=sum)$count==2000),nrow(bins)==4*4*20)
  p1 <- ggplot(d,aes(iteration,value,colour=chain,linetype=chain))+
    geom_line(linewidth=.17,alpha=.72)+facet_wrap(~quantity,ncol=1,scales='free_y')+
    scale_colour_manual(values=cols)+scale_linetype_manual(values=lines)+
    scale_x_continuous(breaks=c(1,1000,2000),expand=expansion(mult=c(.01,.01)))+
    labs(x='Retained iteration',y=NULL)+theme_case()+theme(axis.text=element_text(size=8),strip.text=element_text(size=9))
  p2 <- ggplot(bins,aes(center,count,colour=chain,linetype=chain))+
    geom_hline(yintercept=100,colour='grey75',linewidth=.3)+
    geom_line(linewidth=.35)+facet_wrap(~quantity,ncol=1)+
    scale_colour_manual(values=cols)+scale_linetype_manual(values=lines)+
    scale_x_continuous(breaks=c(1,4000,8000),limits=c(.5,8000.5),expand=expansion(mult=c(.01,.01)))+
    labs(x='Pooled rank',y='Count per chain / bin')+theme_case()+
    theme(axis.text=element_text(size=8),strip.text=element_text(size=9))
  draw <- function() {
    grid::grid.newpage()
    print(p1,newpage=FALSE,vp=grid::viewport(x=.25,y=.5,width=.5,height=1))
    print(p2,newpage=FALSE,vp=grid::viewport(x=.75,y=.5,width=.5,height=1))
  }
  tex <- file.path(here,'figures',paste0(name,'.tex'));png <- file.path(here,'figures',paste0(name,'.png'))
  tikz(tex,standAlone=FALSE,width=5.32,height=5.90,pointsize=10);draw();dev.off()
  grDevices::png(png,width=5.32,height=5.90,units='in',res=180,bg='white');draw();dev.off()
  outputs[[name]] <<- list(tex_sha256=sha(tex),preview_sha256=sha(png),width_in=5.32,height_in=5.90)
}
save_trace('SPS10','v4-trace-sps10');save_trace('Manitoba','v4-trace-mb')
write_json(list(status='RENDERED_FROM_CHECKED_V4_OUTPUTS',generator_sha256=sha(script),inputs=inputs,outputs=outputs,
                fonts='fbb text; Garamond MathDesign math; actual PDF inspection still required'),
           file.path(here,'figures/v4-render-receipt.json'),pretty=TRUE,auto_unbox=TRUE,digits=17)
cat('Rendered four v4 ggplot2/TikZ figures.\n')
