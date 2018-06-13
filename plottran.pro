pro plottran, ss, psname=psname

au = ss.constants.au/ss.constants.rsun ;; AU in rsun (~215)

aspect_ratio=1.5
mydevice=!d.name
if keyword_set(psname) then begin
   set_plot, 'PS'
   aspect_ratio=1.5
   xsize=10.5
   ysize=xsize/aspect_ratio
   ysize = xsize/aspect_ratio + (ss.ntran-1)*0.6
;   ysize=(xsize/aspect_ratio + (ss.ntran)*0.2) < screen[1]
   !p.font=0
   device, filename=psname, /color, bits=24, encapsulated=0
   device, xsize=xsize,ysize=ysize
   loadct, 39, /silent
   red = 254
   symsize = 0.33
   black = 0
   charsize = 0.75
endif else begin
   !p.multi=0
   screen = GET_SCREEN_SIZE()
   device,window_state=win_state
   xsize = 600
   ysize=(xsize/aspect_ratio + (ss.ntran)*150) < screen[1]
   if win_state[30] then wset, 30 $
   else window, 30, xsize=xsize, ysize=ysize, xpos=screen[0]/3d0, ypos=0, retain=2
   red = '0000ff'x
   black = 'ffffff'x
   symsize = 0.5         
   charsize = 1.0
endelse
plotsym, 0, /fill, color=black

;; breaks for grazing transits...
depth = max(ss.planet.p.value^2)

noise = 0d0
for i=0, ss.ntran-1 do if stddev((*(ss.transit[i].transitptrs)).residuals) gt noise then noise = stddev((*(ss.transit[i].transitptrs)).residuals)
if keyword_set(noresiduals) then spacing = (depth+noise)*3d0 $
else spacing = (depth+noise)*4d0

cosi = ss.planet.cosi.value
sini = sin(acos(cosi))
e = ss.planet.secosw.value^2 + ss.planet.sesinw.value^2
circular = where(e eq 0d0, complement=eccentric)
omega = e*0d0
if circular[0] ne -1 then omega[circular] = !dpi/2d0 
if eccentric[0] ne -1 then omega[eccentric] = atan((ss.planet.sesinw.value)[eccentric],(ss.planet.secosw.value)[eccentric])

esinw = e*sin(omega)
ecosw = e*cos(omega)
ar = ss.planet.ar.value
period = ss.planet.period.value
p = ss.planet.p.value

bp = ar*cosi*(1d0-e^2)/(1d0+esinw)
t14 = period/!dpi*asin(sqrt((1d0+p)^2 - bp^2)/(sini*ar))*$
      sqrt(1d0-e^2)/(1d0+esinw)

;;secondary eclipse time
phase = exofast_getphase(e,omega,/primary)
phase2 = exofast_getphase(e,omega,/secondary)
ts = ss.planet.tc.value - ss.planet.period.value*(phase-phase2)

xmax = max(t14)*36d0
xmin = -xmax
xrange = [xmin,xmax]

j=0
trandata = (*(ss.transit[j].transitptrs)) 
time = (trandata.bjd - ss.planet[ss.transit[j].pndx].tc.value - ss.transit[j].epoch*ss.planet[ss.transit[j].pndx].period.value + ss.transit[j].ttv.value)*24.d0

xmin = min(time,max=xmax)
xrange=[xmin,xmax]

maxnoise = stddev((*(ss.transit[0].transitptrs)).residuals)
minnoise = stddev((*(ss.transit[ss.ntran-1].transitptrs)).residuals)
ymin = 1d0 - depth - spacing/2d0 - 3*minnoise
if ss.ntran eq 1 then ymax = 1+3*maxnoise $
else ymax = 1d0 + 3*maxnoise + spacing*(ss.ntran - 0.5)
yrange = [ymin,ymax]

i=0
sini = sin(acos(ss.planet[i].cosi.value))
esinw = ss.planet[i].e.value*sin(ss.planet[i].omega.value)
bp = ss.planet[i].ar.value*ss.planet[i].cosi.value*(1d0-ss.planet[i].e.value^2)/(1d0+esinw)
t14 = (ss.planet[i].period.value/!dpi*asin(sqrt((1d0+ss.planet[i].p.value)^2 - bp^2)/(sini*ss.planet[i].ar.value))*sqrt(1d0-ss.planet[i].e.value^2)/(1d0+esinw))*24d0

trandata = (*(ss.transit[0].transitptrs)) 
minbjd = min(trandata.bjd,max=maxbjd)
minbjd -= 0.25 & maxbjd += 0.25d0
t0 = floor(minbjd)

if maxbjd - minbjd lt 1 then begin
   xrange=[-t14,t14]
   xtitle='!3Time - T!DC!N (hrs)'   
endif else begin
   xrange = [minbjd,maxbjd]-t0
   xtitle='!3' + exofast_textoidl('BJD_{TDB}') + ' - ' + strtrim(t0,2)
endelse

;; position keyword required for proper bounding box
plot, [0],[0],yrange=yrange, xrange=xrange,/xstyle,/ystyle,$;position=[0.15, 0.05, 0.93, 0.93],$
      ytitle='!3Normalized flux + Constant',xtitle=xtitle

;; make a plot for each input file
for j=0, ss.ntran-1 do begin

   trandata = (*(ss.transit[j].transitptrs)) 
   band = ss.band[ss.transit[j].bandndx]
   
   minbjd = min(trandata.bjd,max=maxbjd)
   minbjd -= 0.25 & maxbjd += 0.25d0
   npretty = ceil((maxbjd-minbjd)*1440d0) ;; 1 per minute
   prettytime = minbjd + (maxbjd-minbjd)*dindgen(npretty)/(npretty-1d0)
   prettyflux = dblarr(npretty) + 1d0
   modelflux = trandata.bjd*0 + 1d0

   ;; get the motion of the star due to the planet
   junk = exofast_getb2(prettytime,inc=ss.planet.i.value,a=ss.planet.ar.value,$
                        tperiastron=ss.planet.tp.value,$
                        period=ss.planet.period.value,$
                        e=ss.planet.e.value,omega=ss.planet.omega.value,$
                        q=ss.star.mstar.value/ss.planet.mpsun.value,$
                        x1=x1,y1=y1,z1=z1)

   for i=0, ss.nplanets-1 do begin

      if ss.planet[i].fittran then begin

         tmpflux = (exofast_tran(prettytime, $
                                 ss.planet[i].i.value, $
                                 ss.planet[i].ar.value, $
                                 ss.planet[i].tp.value, $
                                 ss.planet[i].period.value, $
                                 ss.planet[i].e.value,$
                                 ss.planet[i].omega.value,$
                                 ss.planet[i].p.value,$
                                 band.u1.value, $
                                 band.u2.value, $
                                 1d0, $
                                 q=ss.star.mstar.value/ss.planet[i].mpsun.value, $
                                 thermal=band.thermal.value, $
                                 reflect=band.reflect.value, $
                                 dilute=band.dilute.value,$
                                 tc=ss.planet[i].tc.value,$
                                 rstar=ss.star.rstar.value/AU,$
                                 x1=x1,y1=y1,z1=z1) - 1d0) 
         prettyflux += tmpflux
         ;; if there's more than one planet, output separate model files for each
         if keyword_set(psname) and ss.nplanets gt 1 then begin
            base = file_dirname(psname) + path_sep() + file_basename(psname,'.transit.ps')
            exofast_forprint, prettytime, tmpflux, format='(f0.8,x,f0.6)', textout=base + '.transit_' + strtrim(j,2) + '.planet_' + strtrim(i,2) + '.txt', /nocomment,/silent
         endif

         tmpflux = (exofast_tran(trandata.bjd, $
                                 ss.planet[i].i.value, $
                                 ss.planet[i].ar.value, $
                                 ss.planet[i].tp.value, $
                                 ss.planet[i].period.value, $
                                 ss.planet[i].e.value,$
                                 ss.planet[i].omega.value,$
                                 ss.planet[i].p.value,$
                                 band.u1.value, $
                                 band.u2.value, $
                                 1d0, $
                                 q=ss.star.mstar.value/ss.planet[i].mpsun.value, $
                                 thermal=band.thermal.value, $
                                 reflect=band.reflect.value, $
                                 dilute=band.dilute.value,$
                                 tc=ss.planet[i].tc.value,$
                                 rstar=ss.star.rstar.value/AU,$
                                 x1=x1,y1=y1,z1=z1) - 1d0) 
         modelflux += tmpflux

         minepoch = floor((minbjd-ss.planet[i].tc.value)/ss.planet[i].period.value)
         maxepoch = ceil((maxbjd-ss.planet[i].tc.value)/ss.planet[i].period.value)
         epochs = -minepoch + dindgen(maxepoch-minepoch+1)
         tcs = ss.planet[i].tc.value + epochs*ss.planet[i].period.value
         xyouts, tcs-t0, epochs*0d0+(ymax+1d0)/2d0, ss.planet[i].label, align=0.5d0
         
      endif
   endfor
   period = ss.planet[ss.transit[j].pndx].period.value

   if maxbjd - minbjd lt 1 then begin
      time = (trandata.bjd - ss.planet[ss.transit[j].pndx].tc.value - ss.transit[j].epoch[ss.transit[j].pndx]*ss.planet[ss.transit[j].pndx].period.value + ss.transit[j].ttv.value)*24.d0

      good = where(time ge xrange[0] and time le xrange[1], ngood)
      if ngood eq 0 then begin
         time = (trandata.bjd - ts[ss.transit[j].pndx] - ss.transit[j].epoch[ss.transit[j].pndx]*ss.planet[ss.transit[j].pndx].period.value + ss.transit[j].ttv.value)*24.d0
         prettytime = (prettytime - ts[ss.transit[j].pndx] - ss.transit[j].epoch[ss.transit[j].pndx]*ss.planet[ss.transit[j].pndx].period.value + ss.transit[j].ttv.value)*24.d0         
      endif else prettytime = (prettytime - ss.planet[ss.transit[j].pndx].tc.value  - ss.transit[j].epoch[ss.transit[j].pndx]*ss.planet[ss.transit[j].pndx].period.value + ss.transit[j].ttv.value)*24.d0

   endif else begin
      time = trandata.bjd - t0
      prettytime -= t0
   endelse

;   tmp = trandata.flux / (ss.transit[j].f0.value + total(trandata.detrendmult*(replicate(1d0,n_elements(trandata.bjd))##trandata.detrendmultpars.value),1))
;   tmp -= total(trandata.detrendadd*(replicate(1d0,n_elements(trandata.bjd))##trandata.detrendaddpars.value),1)
;   set_plot, 'x'
;   plot, tmp - (modelflux+trandata.residuals)
;   stop

   oplot, time, modelflux + trandata.residuals + spacing*(ss.ntran-j-1), psym=8, symsize=symsize
   oplot, prettytime, prettyflux + spacing*(ss.ntran-j-1), thick=2, color=red;, linestyle=0
   xyouts, 0, 1.0075 + spacing*(ss.ntran-j-1), trandata.label,charsize=charsize,alignment=0.5

endfor

;; make a phased plot for each planet
ntranfit = n_elements(where(ss.planet.fittran))
nx = ceil(sqrt(ntranfit))
ny = ceil(ntranfit/double(nx))
!p.multi = [0,nx,ny]
ysize = xsize/aspect_ratio
if keyword_set(psname) then begin
   device, xsize=xsize,ysize=ysize
endif else begin
   if win_state[31] then wset, 31 $
   else window, 31, xsize=xsize, ysize=ysize, xpos=screen[0]/3d0, ypos=0, retain=2
endelse
trandata = (*(ss.transit[0].transitptrs)) 

for i=0L, ss.nplanets-1 do begin
   
   if ss.planet[i].fittran then begin
      ymax = 1d0 + 3*maxnoise ;+ spacing*((ss.ntran-1d0)>0)

      time = []
      residuals = []
      for j=0L, ss.ntran-1 do begin
         time = [time, (*(ss.transit[j].transitptrs)).bjd - ss.transit[j].ttv.value] 
         residuals = [residuals, (*(ss.transit[j].transitptrs)).residuals] 
      endfor

      ;; get the motion of the star due to the planet
      junk = exofast_getb2(time,inc=ss.planet.i.value,a=ss.planet.ar.value,$
                           tperiastron=ss.planet.tp.value,$
                           period=ss.planet.period.value,$
                           e=ss.planet.e.value,omega=ss.planet.omega.value,$
                           q=ss.star.mstar.value/ss.planet.mpsun.value,$
                           x1=x1,y1=y1,z1=z1)


      ;time = trandata.bjd ; (trandata.bjd-ss.planet[i].tc.value) mod ss.planet[i].period.value     
      modelflux = (exofast_tran(time, $
                                ss.planet[i].i.value, $
                                ss.planet[i].ar.value, $
                                ss.planet[i].tp.value, $
                                ss.planet[i].period.value, $
                                ss.planet[i].e.value,$
                                ss.planet[i].omega.value,$
                                ss.planet[i].p.value,$
                                band.u1.value, $
                                band.u2.value, $
                                1d0, $
                                q=ss.star.mstar.value/ss.planet[i].mpsun.value, $
                                thermal=band.thermal.value, $
                                reflect=band.reflect.value, $
                                dilute=band.dilute.value,$
                                tc=ss.planet[i].tc.value,$
                                rstar=ss.star.rstar.value/AU,$
                                x1=x1,y1=y1,z1=z1) - 1d0) + 1d0
       
      ymin = min(modelflux) - 3d0*minnoise

      phasetime = ((time - ss.planet[i].tc.value) mod ss.planet[i].period.value)*24d0
      toohigh = where(phasetime gt (ss.planet[i].period.value/2d0*24d0))
      if toohigh[0] ne -1 then phasetime[toohigh] -= ss.planet[i].period.value*24d0
      toolow = where(phasetime lt (-ss.planet[i].period.value/2d0*24d0))
      if toolow[0] ne -1 then phasetime[toolow] += ss.planet[i].period.value*24d0
      sorted = sort(phasetime)

      sini = sin(acos(ss.planet[i].cosi.value))
      esinw = ss.planet[i].e.value*sin(ss.planet[i].omega.value)
      bp = ss.planet[i].ar.value*ss.planet[i].cosi.value*(1d0-ss.planet[i].e.value^2)/(1d0+esinw)
      t14 = (ss.planet[i].period.value/!dpi*asin(sqrt((1d0+ss.planet[i].p.value)^2 - bp^2)/(sini*ss.planet[i].ar.value))*sqrt(1d0-ss.planet[i].e.value^2)/(1d0+esinw))*24d0

      ;; plot the shell, model, and data
      plot, [0],[0], xstyle=1,ystyle=1,$
            ytitle='!3Normalized flux',yrange=[ymin,ymax],xrange=[-t14,t14],$
            xtitle='!3Time - Tc (Hrs)',title=ss.planet[i].label
      oplot, phasetime, residuals + modelflux, psym=8, symsize=symsize
      oplot, phasetime[sorted], modelflux[sorted], thick=2, color=red, linestyle=0

      ;;  pad the plot to the nearest 5 in the second sig-fig
;      ymin = round5(min(trandata.residuals + modelflux - trandata.err,/nan))
;      ymax = round5(max(trandata.residuals + modelflux + trandata.err,/nan))
      
      ;; make the plot symmetric about 0
;      if ymin lt -ymax then ymax = -ymin
;      if ymax gt -ymin then ymin = -ymax
      
;      ;; plot the residuals below
;      plot, [0],[0],xstyle=1,ystyle=1, yrange=[ymin,ymax],ytitle='O-C',$
;            xrange=[xmin,xmax],xtitle=xtitle,position=position2,/noerase,$
;            yminor=2,yticks=2,/ynoz
;      oplot, time,trandata.residuals,psym=8,symsize=symsize
;      oplot, [xmin,xmax],[0,0],linestyle=2,color=red  

   endif
endfor
!p.multi=0

if keyword_set(psname) then begin
   device, /close
endif
set_plot, mydevice

end
