import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = {
    initialStart: String,
    initialEnd: String,
    placeholderStart: { type: String, default: 'YYYY-MM-DD' },
    placeholderEnd: { type: String, default: 'YYYY-MM-DD' },
    nameStart: String,
    nameEnd: String,
  };

  connect() {
    this.start = this.#clampDay(this.#parseDate(this.initialStartValue) || null);
    this.end = this.#clampDay(this.#parseDate(this.initialEndValue) || null);
    this.hovered = null;
    this.view = this.start || new Date();
    this.typedStart = this.#formatDate(this.start);
    this.typedEnd = this.#formatDate(this.end);

    this.#render();
  }

  setRange({ start, end }) {
    this.start = start ? this.#clampDay(new Date(start)) : null;
    this.end = end ? this.#clampDay(new Date(end)) : null;
    this.typedStart = this.#formatDate(this.start);
    this.typedEnd = this.#formatDate(this.end);
    this.view = this.start || this.view || new Date();
    this.#render();
    this.#emitChange();
  }

  getRange() { return { start: this.start, end: this.end }; }

  #startOfMonth(d) { const x = new Date(d); x.setDate(1); x.setHours(0, 0, 0, 0); return x; }
  #endOfMonth(d) { const x = new Date(d); x.setMonth(x.getMonth() + 1, 0); x.setHours(23, 59, 59, 999); return x; }
  #addMonths(d, n) { const x = new Date(d); x.setMonth(x.getMonth() + n); return x; }
  #isSameDay(a, b) { return a && b && a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }
  #isBefore(a, b) { return a && b && (new Date(a)).setHours(0, 0, 0, 0) < (new Date(b)).setHours(0, 0, 0, 0); }
  #clampDay(d) { if (!d) return null; const x = new Date(d); x.setHours(0, 0, 0, 0); return x; }
  #formatDate(d) {
    if (!d) return '';
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }
  #parseDate(str) {
    if (!str) return null;
    const s = String(str).trim();

    let m = s.match(/^\s*(\d{4})-(\d{1,2})-(\d{1,2})\s*$/);
    if (m) {
      const y = +m[1], mo = +m[2] - 1, d = +m[3];
      const dt = new Date(y, mo, d);
      return dt.getMonth() === mo && dt.getDate() === d ? dt : null;
    }

    m = s.match(/^\s*(\d{1,2})\/(\d{1,2})\/(\d{4})\s*$/);
    if (m) {
      const mo = +m[1] - 1, d = +m[2], y = +m[3];
      const dt = new Date(y, mo, d);
      return dt.getMonth() === mo && dt.getDate() === d ? dt : null;
    }

    return null;
  }
  #monthMatrix(viewDate) {
    const start = this.#startOfMonth(viewDate);
    const end = this.#endOfMonth(viewDate);
    const firstDay = new Date(start);
    const dayOfWeek = (firstDay.getDay() + 7) % 7;
    firstDay.setDate(firstDay.getDate() - dayOfWeek);
    const weeks = [];
    let cur = new Date(firstDay);
    for (let w = 0; w < 6; w++) {
      const week = [];
      for (let d = 0; d < 7; d++) {
        week.push(new Date(cur));
        cur.setDate(cur.getDate() + 1);
      }
      weeks.push(week);
    }
    return { weeks, start, end };
  }

  #formatInputDate(v) {
    let value = v.replace(/\D/g, "");
    if (value.length > 8) value = value.slice(0, 8);

    if (value.length > 6) {
      value = value.replace(/(\d{4})(\d{2})(\d{0,2})/, "$1-$2-$3");
    } else if (value.length > 4) {
      value = value.replace(/(\d{4})(\d{0,2})/, "$1-$2");
    }
    return value;
  }


  #render() {
    this.element.innerHTML = this.#template();

    this.$typedStart = this.element.querySelector('[data-role="typed-start"]');
    this.$typedEnd = this.element.querySelector('[data-role="typed-end"]');
    this.$prevBtn = this.element.querySelector('[data-role="prev-month"]');
    this.$nextBtn = this.element.querySelector('[data-role="next-month"]');
    this.$monthTitle = this.element.querySelector('[data-role="month-title"]');
    this.$weeksGrid = this.element.querySelector('[data-role="weeks"]');
    this.$reset = this.element.querySelector('[data-role="reset"]');

    this.$typedStart.addEventListener("input", (e) => {
      const value = this.#formatInputDate(e.target.value);
      this.typedStart = value;
      this.$typedStart.value = value;
    });

    this.$typedEnd.addEventListener("input", (e) => {
      const value = this.#formatInputDate(e.target.value);
      this.typedEnd = value;
      this.$typedEnd.value = value;
    });

    this.$typedStart.addEventListener('blur', () => this.#commitTyped('start'));
    this.$typedEnd.addEventListener('blur', () => this.#commitTyped('end'));

    this.$prevBtn.addEventListener('click', () => { this.view = this.#addMonths(this.view, -1); this.#renderCalendar(); });
    this.$nextBtn.addEventListener('click', () => { this.view = this.#addMonths(this.view, 1); this.#renderCalendar(); });


    this.$reset.addEventListener('click', () => { this.start = null; this.end = null; this.#renderCalendar(); this.#emitChange(); });
    this.#renderCalendar();
  }

  #renderCalendar() {
    const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    this.$monthTitle.textContent = `${monthNames[this.view.getMonth()]} ${this.view.getFullYear()}`;

    const { weeks, start: mStart } = this.#monthMatrix(this.view);
    const flat = weeks.flat();
    const frag = document.createDocumentFragment();

    flat.forEach((day) => {
      const selectedStart = this.start && this.#isSameDay(day, this.start);
      const selectedEnd = this.end && this.#isSameDay(day, this.end);
      const between = this.#inRange(day);
      const muted = (day.getMonth() !== mStart.getMonth());

      let bg = between ? 'bg-info text-white' : 'bg-transparent';
      let text = muted ? 'text-gray-400' : 'text-gray-800';
      // let ring = (selectedStart || selectedEnd) ? 'ring-2 ring-gray-500' : 'ring-1 ring-gray-200';
      let rounded = 'rounded-xl';

      const btn = document.createElement('button');
      btn.type = 'button';
      btn.setAttribute('aria-label', day.toDateString());
      btn.className = `border-0 relative ${rounded} ${bg} ${text} h-7 select-none text-sm transition-shadow hover:shadow-sm focus:outline-none focus-visible:ring-2 focus-visible:ring-black`;
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.#pickDay(this.#clampDay(day))
      });
      btn.addEventListener('mouseenter', () => { this.hovered = this.#clampDay(day); this.#updateCalendarHover(); });
      btn.addEventListener('mouseleave', () => { this.hovered = null; this.#updateCalendarHover(); });

      const span = document.createElement('span');
      span.className = `inline-flex h-full w-full items-center justify-center ${selectedStart || selectedEnd ? 'font-semibold' : ''}`;
      span.textContent = String(day.getDate());

      btn.appendChild(span);
      frag.appendChild(btn);
    });

    this.$weeksGrid.replaceChildren(frag);

    this.$typedStart.value = this.start ? this.#formatDate(this.start) : '';
    this.$typedEnd.value = this.end ? this.#formatDate(this.end) : '';
  }

  #updateCalendarHover() {
    this.#renderCalendar();
  }

  #pickDay(day) {
    if (!this.start || (this.start && this.end)) {
      this.start = day; this.end = null; this.view = day;
    } else if (this.start && !this.end) {
      if (this.#isBefore(day, this.start)) { this.end = this.start; this.start = day; }
      else { this.end = day; }
    }
    this.typedStart = this.#formatDate(this.start);
    this.typedEnd = this.#formatDate(this.end);
    this.#renderCalendar();
    this.#emitChange();
  }

  #inRange(day) {
    if (this.start && this.end) { return !this.#isBefore(day, this.start) && !this.#isBefore(this.end, day); }
    if (this.start && this.hovered) {
      const a = this.#isBefore(this.hovered, this.start) ? this.hovered : this.start;
      const b = this.#isBefore(this.hovered, this.start) ? this.start : this.hovered;
      return !this.#isBefore(day, a) && !this.#isBefore(b, day);
    }
    return false;
  }

  #commitTyped(which) {
    if (which === 'start') {
      const d = this.#parseDate(this.typedStart);
      if (d) {
        const day = this.#clampDay(d);
        if (this.end && this.#isBefore(this.end, day)) this.end = null;
        this.start = day; this.view = day;
        this.#renderCalendar();
        this.#emitChange();
      }
      else {
        this.$typedStart.value = '';
      }
    } else {
      const d = this.#parseDate(this.typedEnd);
      if (d) {
        const day = this.#clampDay(d);
        if (this.start && this.#isBefore(day, this.start)) this.start = day;
        this.end = day;
        this.#renderCalendar();
        this.#emitChange();
      }
      else {
        // invalid end date clears it
        this.$typedEnd.value = '';
      }
    }
  }

  #emitChange() {
    this.element.dispatchEvent(new CustomEvent('daterange:change', {
      bubbles: true,
      detail: { start: this.start, end: this.end }
    }));
  }

  #template() {
    return `
      <div class="w-full max-w-xl">
        <div class="flex items-center gap-3 mb-3">
          <div class="relative flex-1">
            <input name="${this.nameStartValue}" class="input text-center" data-role="typed-start" placeholder="${this.placeholderStartValue}" value="${this.typedStart ?? ''}" />
          </div>
          <span class="text-gray-400 select-none">to</span>
          <div class="relative flex-1">
            <input name="${this.nameEndValue}" class="input text-center" data-role="typed-end" placeholder="${this.placeholderEndValue}" value="${this.typedEnd ?? ''}" />
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between pb-2 px-1">
            <button type="button" data-role="prev-month" class="pop">←</button>
            <div data-role="month-title" class="text-lg font-[700]"></div>
            <button type="button" data-role="next-month" class="pop">→</button>
          </div>

          <div class="grid grid-cols-7 gap-1 text-center text-xs text-gray-500">
            ${['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].map(d => `<div class="py-1">${d}</div>`).join('')}
          </div>

          <div data-role="weeks" class="grid grid-cols-7 gap-1 py-2"></div>

          <div class="flex gap-2 my-2">
            <button type="reset" data-role="reset" class="btn btn-small bg-muted flex-1">Clear</button>
            <button type="submit" class="btn btn-small flex-1">Filter...</button>
          </div>
        </div>
      </div>
    `;
  }
}
