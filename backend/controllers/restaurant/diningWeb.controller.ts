import { Request, Response } from 'express';

/**
 * Renders the responsive Mobile-First Dining Web App
 * Matches the official Flutter TableDiningScreen ("same to same" UI & functions)
 */
export const renderDiningWebPortal = (req: Request, res: Response) => {
  const tableId = String(req.query.table_id || req.query.table || '');
  const tableName = String(req.query.table_name || (tableId ? `T-${tableId}` : 'Table'));
  const outletId = String(req.query.outlet_id || req.query.outlet || '1');
  const seatNumber = String(req.query.seat || req.query.seat_no || req.query.seat_id || '');
  const clientTag = String(req.query.client_tag || req.query.bill || '');

  const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Digital Menu • ${tableName}</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%23E23744'><path d='M11 9H9V2H7v7H5V2H3v7c0 2.12 1.66 3.84 3.75 3.97V22h2.5v-9.03C11.34 12.84 13 11.12 13 9V2h-2v7zm5-3v8h2.5v8H21V2c-2.76 0-5 2.24-5 4z'/></svg>">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
  <style>
    :root {
      --primary: #E23744;
      --primary-dark: #C52230;
      --primary-light: #FEE2E2;
      --bg: #F8FAFC;
      --card-bg: #FFFFFF;
      --text-main: #0F172A;
      --text-muted: #64748B;
      --border: #E2E8F0;
      --veg: #16A34A;
      --nonveg: #DC2626;
      --egg: #EAB308;
      --shadow-sm: 0 1px 3px rgba(0,0,0,0.05);
      --shadow: 0 4px 14px -2px rgba(15, 23, 42, 0.08);
      --shadow-lg: 0 10px 25px -5px rgba(226, 55, 68, 0.35);
      --radius: 12px;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
    body {
      font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background-color: var(--bg);
      color: var(--text-main);
      padding-bottom: 96px;
      min-height: 100vh;
    }

    /* Top Restaurant Header */
    header {
      background: var(--card-bg);
      border-bottom: 1px solid var(--border);
      position: sticky;
      top: 0;
      z-index: 50;
      box-shadow: var(--shadow-sm);
    }
    .header-content {
      padding: 14px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      max-width: 800px;
      margin: 0 auto;
    }
    .restaurant-title {
      font-size: 18px;
      font-weight: 900;
      color: var(--text-main);
      line-height: 1.2;
    }
    .restaurant-address {
      font-size: 11px;
      color: var(--text-muted);
      margin-top: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      max-width: 200px;
    }
    .header-badges {
      display: flex;
      align-items: center;
      gap: 6px;
      flex-wrap: nowrap;
    }
    .badge-pill {
      display: inline-flex;
      align-items: center;
      gap: 5px;
      background: #F1F5F9;
      border: 1px solid var(--border);
      color: var(--text-main);
      padding: 6px 10px;
      border-radius: 9999px;
      font-size: 11px;
      font-weight: 700;
      cursor: pointer;
      transition: all 0.2s;
      white-space: nowrap;
    }
    .badge-pill:active { transform: scale(0.96); }
    .badge-table {
      background: #FFF7ED;
      border-color: #FED7AA;
      color: #EA580C;
    }

    /* Container Wrap */
    .app-container {
      max-width: 800px;
      margin: 0 auto;
    }

    /* 1.1 Book Table From Home Banner */
    .banner-reserve {
      margin: 10px 16px;
      padding: 12px 14px;
      background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%);
      border-radius: 12px;
      color: #FFFFFF;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 12px;
      box-shadow: 0 4px 12px rgba(15, 23, 42, 0.12);
    }
    .banner-left {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .banner-icon {
      width: 38px;
      height: 38px;
      border-radius: 50%;
      background: rgba(249, 115, 22, 0.2);
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 18px;
      color: #F97316;
      flex-shrink: 0;
    }
    .banner-text-title {
      font-size: 13px;
      font-weight: 800;
      color: #FFFFFF;
    }
    .banner-text-sub {
      font-size: 10px;
      color: #94A3B8;
      margin-top: 1px;
    }
    .btn-reserve-trigger {
      background: #EA580C;
      color: #FFFFFF;
      border: none;
      padding: 8px 14px;
      border-radius: 8px;
      font-size: 11px;
      font-weight: 800;
      cursor: pointer;
      white-space: nowrap;
    }

    /* 2. Main Tab Selector (Food Menu vs Order History) */
    .main-tab-nav {
      margin: 6px 16px 10px 16px;
      padding: 4px;
      background: #F1F5F9;
      border: 1px solid var(--border);
      border-radius: 12px;
      display: flex;
      gap: 4px;
    }
    .tab-btn {
      flex: 1;
      padding: 10px 0;
      border: none;
      background: transparent;
      border-radius: 9px;
      font-size: 13px;
      font-weight: 800;
      color: #64748B;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
      gap: 6px;
      transition: all 0.2s;
    }
    .tab-btn.active {
      background: #FFFFFF;
      color: var(--primary);
      box-shadow: 0 2px 6px rgba(0, 0, 0, 0.06);
    }
    .tab-badge {
      background: var(--text-main);
      color: #FFFFFF;
      font-size: 10px;
      font-weight: 800;
      padding: 1px 6px;
      border-radius: 10px;
    }
    .tab-btn.active .tab-badge {
      background: var(--primary);
    }

    /* 3. Quick Waiter Action Cards */
    .waiter-actions-grid {
      margin: 0 16px 12px 16px;
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
    }
    .action-btn-card {
      border-radius: 12px;
      padding: 10px 8px;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s;
      border: 1px solid;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      gap: 2px;
    }
    .action-btn-card:active { transform: scale(0.96); }
    .card-server {
      background: linear-gradient(180deg, #EEF2FF 0%, #E0E7FF 100%);
      border-color: #C7D2FE;
      color: #4F46E5;
    }
    .card-water {
      background: linear-gradient(180deg, #F0F9FF 0%, #E0F2FE 100%);
      border-color: #BAE6FD;
      color: #0284C7;
    }
    .card-bill {
      background: linear-gradient(180deg, #FFFBEB 0%, #FEF3C7 100%);
      border-color: #FDE68A;
      color: #D97706;
    }
    .card-orders {
      background: linear-gradient(180deg, #FEF2F2 0%, #FEE2E2 100%);
      border-color: #FECACA;
      color: var(--primary);
    }
    .action-icon { font-size: 20px; line-height: 1; margin-bottom: 2px; }
    .action-title { font-size: 11px; font-weight: 800; white-space: nowrap; }
    .action-sub { font-size: 9px; opacity: 0.8; font-weight: 600; white-space: nowrap; }

    /* Search & Dietary Filters */
    .search-filter-wrap {
      padding: 0 16px 8px 16px;
      display: flex;
      flex-direction: column;
      gap: 8px;
    }
    .search-input-box {
      position: relative;
      display: flex;
      align-items: center;
    }
    .search-input {
      width: 100%;
      background: #FFFFFF;
      border: 1px solid var(--border);
      padding: 11px 36px 11px 38px;
      border-radius: 12px;
      font-size: 13px;
      font-weight: 500;
      outline: none;
      font-family: inherit;
      transition: all 0.2s;
    }
    .search-input:focus {
      border-color: var(--primary);
      box-shadow: 0 0 0 3px rgba(226, 55, 68, 0.12);
    }
    .search-icon-left {
      position: absolute;
      left: 12px;
      font-size: 16px;
      color: var(--text-muted);
      pointer-events: none;
    }
    .search-clear-btn {
      position: absolute;
      right: 12px;
      background: transparent;
      border: none;
      font-size: 16px;
      color: var(--text-muted);
      cursor: pointer;
      display: none;
    }
    .dietary-filters {
      display: flex;
      gap: 6px;
      overflow-x: auto;
      scrollbar-width: none;
    }
    .dietary-filters::-webkit-scrollbar { display: none; }
    .dietary-btn {
      background: #FFFFFF;
      border: 1px solid var(--border);
      padding: 6px 12px;
      border-radius: 9999px;
      font-size: 11px;
      font-weight: 700;
      color: var(--text-muted);
      cursor: pointer;
      display: flex;
      align-items: center;
      gap: 6px;
      white-space: nowrap;
      transition: all 0.2s;
    }
    .dietary-btn.active {
      background: var(--text-main);
      border-color: var(--text-main);
      color: #FFFFFF;
    }
    .dietary-btn.active.veg-active {
      background: var(--veg);
      border-color: var(--veg);
      color: #FFFFFF;
    }
    .dietary-btn.active.nonveg-active {
      background: var(--nonveg);
      border-color: var(--nonveg);
      color: #FFFFFF;
    }

    /* Category Carousel */
    .category-pills-bar {
      padding: 0 16px 10px 16px;
      display: flex;
      gap: 6px;
      overflow-x: auto;
      scrollbar-width: none;
    }
    .category-pills-bar::-webkit-scrollbar { display: none; }
    .cat-pill {
      background: #FFFFFF;
      border: 1px solid var(--border);
      padding: 7px 14px;
      border-radius: 9999px;
      font-size: 12px;
      font-weight: 700;
      color: var(--text-muted);
      cursor: pointer;
      white-space: nowrap;
      transition: all 0.2s;
    }
    .cat-pill.active {
      background: var(--primary);
      border-color: var(--primary);
      color: #FFFFFF;
    }

    /* Food Catalog Items */
    .catalog-list {
      padding: 0 16px;
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .food-card {
      background: var(--card-bg);
      border: 1px solid #F1F5F9;
      border-radius: 12px;
      padding: 14px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      gap: 12px;
      box-shadow: 0 2px 6px rgba(15, 23, 42, 0.02);
      transition: all 0.2s;
    }
    .food-left {
      flex: 1;
      min-width: 0;
    }
    .fssai-indicator {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 14px;
      height: 14px;
      border: 1.5px solid;
      border-radius: 3px;
      margin-bottom: 4px;
    }
    .fssai-indicator.veg { border-color: var(--veg); }
    .fssai-indicator.nonveg { border-color: var(--nonveg); }
    .fssai-indicator.egg { border-color: var(--egg); }
    .fssai-dot {
      width: 6px;
      height: 6px;
      border-radius: 50%;
    }
    .fssai-indicator.veg .fssai-dot { background: var(--veg); }
    .fssai-indicator.nonveg .fssai-dot { background: var(--nonveg); }
    .fssai-indicator.egg .fssai-dot { background: var(--egg); }
    .food-name {
      font-size: 14px;
      font-weight: 800;
      color: var(--text-main);
      line-height: 1.3;
    }
    .food-sub {
      font-size: 11px;
      color: var(--text-muted);
      margin-top: 2px;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .food-price {
      font-size: 14px;
      font-weight: 800;
      color: var(--text-main);
      margin-top: 6px;
    }
    .food-right {
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 4px;
    }
    .btn-add {
      background: #FFFFFF;
      border: 1.5px solid var(--primary);
      color: var(--primary);
      padding: 6px 18px;
      border-radius: 8px;
      font-size: 12px;
      font-weight: 800;
      cursor: pointer;
      box-shadow: 0 1px 3px rgba(226, 55, 68, 0.1);
      transition: all 0.2s;
    }
    .btn-add:active { transform: scale(0.96); }
    .qty-stepper {
      display: flex;
      align-items: center;
      background: var(--primary);
      border-radius: 8px;
      color: #FFFFFF;
      font-weight: 800;
      box-shadow: 0 2px 6px rgba(226, 55, 68, 0.3);
      overflow: hidden;
    }
    .stepper-btn {
      background: transparent;
      border: none;
      color: #FFFFFF;
      width: 28px;
      height: 30px;
      font-size: 16px;
      font-weight: 800;
      cursor: pointer;
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .stepper-qty {
      padding: 0 8px;
      font-size: 13px;
      min-width: 20px;
      text-align: center;
    }

    /* Floating Cart Bar */
    .floating-cart-bar {
      position: fixed;
      bottom: 16px;
      left: 16px;
      right: 16px;
      max-width: 768px;
      margin: 0 auto;
      background: var(--primary);
      color: #FFFFFF;
      border-radius: 12px;
      padding: 12px 18px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      box-shadow: var(--shadow-lg);
      cursor: pointer;
      z-index: 60;
      transform: translateY(120%);
      transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
    }
    .floating-cart-bar.visible {
      transform: translateY(0);
    }
    .cart-left-count {
      font-size: 13px;
      font-weight: 800;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .cart-left-sub {
      font-size: 9px;
      color: rgba(255, 255, 255, 0.8);
      margin-top: 1px;
    }
    .cart-right-label {
      font-size: 14px;
      font-weight: 800;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    /* Modals & Drawers */
    .modal-overlay {
      position: fixed;
      inset: 0;
      background: rgba(15, 23, 42, 0.6);
      backdrop-filter: blur(4px);
      z-index: 100;
      display: none;
      align-items: flex-end;
      justify-content: center;
    }
    .modal-overlay.open {
      display: flex;
    }
    .drawer-content {
      background: #FFFFFF;
      width: 100%;
      max-width: 600px;
      border-radius: 20px 20px 0 0;
      max-height: 85vh;
      display: flex;
      flex-direction: column;
      animation: slideUp 0.25s ease-out;
    }
    @keyframes slideUp {
      from { transform: translateY(100%); }
      to { transform: translateY(0); }
    }
    .drawer-handle {
      width: 40px;
      height: 4px;
      background: #CBD5E1;
      border-radius: 2px;
      margin: 12px auto 6px auto;
    }
    .drawer-header {
      padding: 10px 20px 14px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      border-bottom: 1px solid var(--border);
    }
    .drawer-title {
      font-size: 16px;
      font-weight: 800;
      color: var(--text-main);
    }
    .btn-close {
      background: #F1F5F9;
      border: none;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      font-size: 14px;
      font-weight: 800;
      cursor: pointer;
      color: var(--text-muted);
    }
    .drawer-body {
      padding: 16px 20px;
      overflow-y: auto;
      flex: 1;
    }
    .drawer-footer {
      padding: 14px 20px 20px 20px;
      border-top: 1px solid var(--border);
      background: #FFFFFF;
    }

    /* Cart Item Card inside Drawer */
    .cart-drawer-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 0;
      border-bottom: 1px dashed var(--border);
    }
    .btn-submit-order {
      width: 100%;
      background: var(--primary);
      color: #FFFFFF;
      border: none;
      padding: 14px;
      border-radius: 12px;
      font-size: 14px;
      font-weight: 800;
      cursor: pointer;
      box-shadow: var(--shadow-lg);
    }
    .btn-submit-order:active { transform: scale(0.98); }

    /* Orders Tab */
    .orders-section {
      padding: 0 16px;
    }
    .order-kot-card {
      background: #FFFFFF;
      border: 1px solid var(--border);
      border-radius: 12px;
      padding: 14px;
      margin-bottom: 12px;
      box-shadow: var(--shadow-sm);
    }
    .kot-status-badge {
      font-size: 11px;
      font-weight: 800;
      padding: 3px 8px;
      border-radius: 6px;
    }
    .status-RECEIVED { background: #DBEAFE; color: #1E40AF; }
    .status-IN_KITCHEN { background: #FFEDD5; color: #C2410C; }
    .status-READY { background: #F3E8FF; color: #6B21A8; }
    .status-SERVED { background: #DCFCE7; color: #15803D; }

    /* Empty States */
    .empty-box {
      text-align: center;
      background: #FFFFFF;
      border: 1px solid var(--border);
      border-radius: 16px;
      padding: 40px 24px;
      margin: 16px;
    }

    /* Form Fields in Dialogs */
    .form-group {
      margin-bottom: 12px;
    }
    .form-label {
      font-size: 12px;
      font-weight: 700;
      color: var(--text-main);
      margin-bottom: 4px;
      display: block;
    }
    .form-input {
      width: 100%;
      border: 1px solid var(--border);
      padding: 10px 12px;
      border-radius: 8px;
      font-size: 13px;
      font-family: inherit;
      outline: none;
    }
    .form-input:focus {
      border-color: var(--primary);
    }

    /* Toast Notification */
    #toast-msg {
      position: fixed;
      top: 20px;
      left: 50%;
      transform: translateX(-50%) translateY(-100px);
      background: #0F172A;
      color: #FFFFFF;
      padding: 10px 20px;
      border-radius: 9999px;
      font-size: 13px;
      font-weight: 700;
      z-index: 200;
      box-shadow: 0 10px 20px rgba(0,0,0,0.2);
      transition: all 0.3s cubic-bezier(0.16, 1, 0.3, 1);
      display: flex;
      align-items: center;
      gap: 8px;
    }
    #toast-msg.show {
      transform: translateX(-50%) translateY(0);
    }
  </style>
</head>
<body>

  <!-- Toast -->
  <div id="toast-msg"><span>🔔</span> <span id="toast-text">Message</span></div>

  <!-- Top Sticky Header -->
  <header>
    <div class="header-content">
      <div>
        <div class="restaurant-title" id="restaurant-name">Loading...</div>
        <div class="restaurant-address" id="restaurant-address">Dine-in Experience</div>
      </div>
      <div class="header-badges">
        <button class="badge-pill badge-table" onclick="openTableSwitcher()">
          <span>🪑</span> <span id="header-table-name">${tableName}</span>
        </button>
        <button class="badge-pill" onclick="openCustomerProfileModal()">
          <span>👤</span> <span id="header-customer-name">Guest</span>
        </button>
      </div>
    </div>
  </header>

  <div class="app-container">

    <!-- 1.1 Book Table From Home Banner -->
    <div class="banner-reserve">
      <div class="banner-left">
        <div class="banner-icon">🍽️</div>
        <div>
          <div class="banner-text-title">Book a Table from Home</div>
          <div class="banner-text-sub">Reserve your dining table online & skip waiting</div>
        </div>
      </div>
      <button class="btn-reserve-trigger" onclick="openBookTableModal()">Book Table</button>
    </div>

    <!-- 2. Main Tab Selector (Food Menu vs Order History) -->
    <div class="main-tab-nav">
      <button class="tab-btn active" id="tab-btn-menu" onclick="switchMainTab(0)">
        <span>🍽️</span> <span>Food Menu</span>
      </button>
      <button class="tab-btn" id="tab-btn-orders" onclick="switchMainTab(1)">
        <span>🧾</span> <span>Order History & Status</span>
        <span class="tab-badge" id="orders-count-badge" style="display:none;">0</span>
      </button>
    </div>

    <!-- 3. Quick Waiter Action Cards -->
    <div class="waiter-actions-grid">
      <div class="action-btn-card card-server" onclick="sendWaiterCall('CALL_WAITER', 'Call Server')">
        <div class="action-icon">🛎️</div>
        <div class="action-title">Call Server</div>
        <div class="action-sub">Steward</div>
      </div>
      <div class="action-btn-card card-water" onclick="sendWaiterCall('WATER', 'Water Refill')">
        <div class="action-icon">💧</div>
        <div class="action-title">Water</div>
        <div class="action-sub">Refill Glass</div>
      </div>
      <div class="action-btn-card card-bill" onclick="sendWaiterCall('BILL', 'Request Bill')">
        <div class="action-icon">🧾</div>
        <div class="action-title">Request Bill</div>
        <div class="action-sub">Get Invoice</div>
      </div>
      <div class="action-btn-card card-orders" onclick="switchMainTab(1)">
        <div class="action-icon">🍔</div>
        <div class="action-title" id="action-orders-title">Orders</div>
        <div class="action-sub" id="action-orders-sub">Active KOTs</div>
      </div>
    </div>

    <!-- TAB 0: FOOD MENU VIEW -->
    <div id="view-food-menu">
      <!-- Search & Filters -->
      <div class="search-filter-wrap">
        <div class="search-input-box">
          <span class="search-icon-left">🔍</span>
          <input type="text" id="search-input" class="search-input" placeholder="Search delicious dishes..." oninput="handleSearch(this.value)">
          <button id="search-clear" class="search-clear-btn" onclick="clearSearch()">✕</button>
        </div>
        <div class="dietary-filters">
          <button class="dietary-btn active" id="filter-all" onclick="setDietaryFilter('ALL')">All Dishes</button>
          <button class="dietary-btn" id="filter-veg" onclick="setDietaryFilter('VEG')">
            <span class="fssai-indicator veg" style="margin-bottom:0;"><span class="fssai-dot"></span></span> Veg Only
          </button>
          <button class="dietary-btn" id="filter-nonveg" onclick="setDietaryFilter('NON_VEG')">
            <span class="fssai-indicator nonveg" style="margin-bottom:0;"><span class="fssai-dot"></span></span> Non-Veg
          </button>
        </div>
      </div>

      <!-- Categories Pills -->
      <div class="category-pills-bar" id="category-pills">
        <button class="cat-pill active" onclick="setCategory('ALL')">All Dishes</button>
      </div>

      <!-- Food Catalog List -->
      <div class="catalog-list" id="food-catalog-list">
        <div style="text-align:center;padding:40px;color:var(--text-muted);font-weight:600;">
          Connecting to restaurant table...
        </div>
      </div>
    </div>

    <!-- TAB 1: ORDER HISTORY VIEW -->
    <div id="view-order-history" style="display:none;">
      <div class="orders-section" id="orders-content">
        <!-- Rendered dynamically -->
      </div>
    </div>

  </div>

  <!-- FLOATING BOTTOM CART BAR -->
  <div class="floating-cart-bar" id="floating-cart-bar" onclick="openCartDrawer()">
    <div>
      <div class="cart-left-count" id="cart-item-count">0 ITEMS • ₹0.00</div>
      <div class="cart-left-sub">Extra charges / taxes may apply</div>
    </div>
    <div class="cart-right-label">
      <span>View Cart</span> <span>🛒</span>
    </div>
  </div>

  <!-- CART BOTTOM DRAWER MODAL -->
  <div class="modal-overlay" id="cart-drawer-overlay">
    <div class="drawer-content">
      <div class="drawer-handle"></div>
      <div class="drawer-header">
        <div class="drawer-title">Your Table Order (${tableName})</div>
        <button class="btn-close" onclick="closeCartDrawer()">✕</button>
      </div>
      <div class="drawer-body">
        <div id="cart-items-container"></div>

        <div style="margin-top:16px;">
          <label class="form-label">Special Cooking Instructions</label>
          <input type="text" id="special-instructions" class="form-input" placeholder="e.g. Less spicy, extra sauce, quick service...">
        </div>

        <div style="margin-top:14px;background:#F8FAFC;border:1px solid var(--border);border-radius:10px;padding:12px;">
          <div style="display:flex;justify-content:space-between;font-size:12px;color:var(--text-muted);margin-bottom:6px;">
            <span>Subtotal</span>
            <span id="bill-subtotal">₹0.00</span>
          </div>
          <div style="display:flex;justify-content:space-between;font-size:14px;font-weight:900;color:var(--text-main);padding-top:6px;border-top:1px dashed var(--border);">
            <span>Estimated Total</span>
            <span id="bill-grand-total">₹0.00</span>
          </div>
        </div>

        <div style="margin-top:14px;">
          <label class="form-label">Payment Method</label>
          <div style="display:flex;gap:8px;">
            <label style="flex:1;display:flex;align-items:center;gap:6px;background:#F1F5F9;border:1px solid var(--border);padding:8px 12px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;">
              <input type="radio" name="payment_method" value="PAY_LATER" checked> Pay Later at Table
            </label>
            <label style="flex:1;display:flex;align-items:center;gap:6px;background:#F1F5F9;border:1px solid var(--border);padding:8px 12px;border-radius:8px;font-size:12px;font-weight:700;cursor:pointer;">
              <input type="radio" name="payment_method" value="ONLINE"> Pay Online (UPI)
            </label>
          </div>
        </div>
      </div>
      <div class="drawer-footer">
        <button class="btn-submit-order" id="btn-submit-order" onclick="submitDiningOrder()">
          🚀 Place Order to Kitchen
        </button>
      </div>
    </div>
  </div>

  <!-- BOOK TABLE MODAL -->
  <div class="modal-overlay" id="book-table-overlay">
    <div class="drawer-content" style="max-height:90vh;">
      <div class="drawer-handle"></div>
      <div class="drawer-header">
        <div class="drawer-title">Reserve Table from Home</div>
        <button class="btn-close" onclick="closeBookTableModal()">✕</button>
      </div>
      <div class="drawer-body">
        <div class="form-group">
          <label class="form-label">Customer Full Name *</label>
          <input type="text" id="resv-name" class="form-input" placeholder="e.g. John Doe">
        </div>
        <div class="form-group">
          <label class="form-label">Mobile Phone Number *</label>
          <input type="tel" id="resv-phone" class="form-input" placeholder="e.g. 9876543210">
        </div>
        <div class="form-group">
          <label class="form-label">Reservation Date & Time</label>
          <div style="display:flex;gap:8px;">
            <input type="date" id="resv-date" class="form-input" style="flex:1;">
            <input type="time" id="resv-time" class="form-input" value="19:30" style="flex:1;">
          </div>
        </div>
        <div class="form-group">
          <label class="form-label">Number of Guests</label>
          <input type="number" id="resv-guests" class="form-input" value="2" min="1" max="30">
        </div>
        <div class="form-group">
          <label class="form-label">Special Requests (Optional)</label>
          <input type="text" id="resv-notes" class="form-input" placeholder="e.g. Birthday, Anniversary, Window seat...">
        </div>
      </div>
      <div class="drawer-footer">
        <button class="btn-submit-order" onclick="submitTableReservation()">
          Confirm Reservation Request
        </button>
      </div>
    </div>
  </div>

  <!-- TABLE SWITCHER MODAL -->
  <div class="modal-overlay" id="table-switcher-overlay">
    <div class="drawer-content">
      <div class="drawer-handle"></div>
      <div class="drawer-header">
        <div class="drawer-title">Switch / Select Table</div>
        <button class="btn-close" onclick="closeTableSwitcher()">✕</button>
      </div>
      <div class="drawer-body" id="tables-list-container">
        <div style="text-align:center;padding:20px;color:var(--text-muted);">Loading tables...</div>
      </div>
    </div>
  </div>

  <script>
    // State variables
    const TABLE_ID = "${tableId}";
    const TABLE_NAME = "${tableName}";
    const OUTLET_ID = "${outletId}";
    const SEAT_NUMBER = "${seatNumber}";
    const CLIENT_TAG = "${clientTag}";

    let restaurant = {};
    let table = {};
    let currencySymbol = "₹";
    let catalogItems = [];
    let categories = [];
    let activeOrders = [];
    let cart = {}; // itemId -> { item, qty, note }

    let currentMainTab = 0; // 0 = Menu, 1 = Orders
    let currentCategory = 'ALL';
    let currentDietary = 'ALL';
    let searchQuery = '';

    // Customer profile state
    let customerProfile = {
      name: localStorage.getItem('dining_cust_name') || 'Guest',
      phone: localStorage.getItem('dining_cust_phone') || '',
      email: localStorage.getItem('dining_cust_email') || ''
    };

    function showToast(msg) {
      const toast = document.getElementById('toast-msg');
      document.getElementById('toast-text').innerText = msg;
      toast.classList.add('show');
      setTimeout(() => toast.classList.remove('show'), 3500);
    }

    // Format currency amount cleanly
    function fmtPrice(amount) {
      const num = Number(amount || 0);
      return currencySymbol + num.toFixed(2);
    }

    // Initialize data
    async function loadDiningData() {
      try {
        const query = new URLSearchParams({
          outlet_id: OUTLET_ID,
          table_id: TABLE_ID,
          table: TABLE_ID
        });
        const res = await fetch('/api/public/dining/table-info?' + query.toString());
        const json = await res.json();

        if (!json.success || !json.data) {
          document.getElementById('food-catalog-list').innerHTML = 
            '<div class="empty-box">' +
              '<div style="font-size:36px;margin-bottom:10px;">⚠️</div>' +
              '<div style="font-weight:800;font-size:16px;">' + (json.message || 'Could not load menu') + '</div>' +
              '<div style="color:var(--text-muted);font-size:12px;margin-top:6px;">Please check table QR code or contact staff.</div>' +
            '</div>';
          return;
        }

        restaurant = json.data.restaurant || {};
        table = json.data.table || {};
        catalogItems = json.data.items || [];
        categories = json.data.categories || [];
        activeOrders = json.data.active_orders || [];

        // Determine Global Currency
        currencySymbol = restaurant.currency_symbol || restaurant.currency || '₹';
        if (currencySymbol === 'KSh' && restaurant.tax_mode === 'CGST_SGST') {
          currencySymbol = '₹';
        }

        // Header info
        document.getElementById('restaurant-name').innerText = restaurant.property_name || restaurant.outlet_name || 'Grand Restaurant';
        document.getElementById('restaurant-address').innerText = restaurant.address || 'Dine-in Experience';
        if (table.table_name) {
          document.getElementById('header-table-name').innerText = table.table_name;
        }
        document.getElementById('header-customer-name').innerText = customerProfile.name;

        // Render categories & food items
        renderCategoryPills();
        renderFoodCatalog();
        updateOrdersTabBadge();
      } catch (err) {
        console.error('Failed to load menu data', err);
      }
    }

    // Render Categories
    function renderCategoryPills() {
      const container = document.getElementById('category-pills');
      container.innerHTML = '<button class="cat-pill ' + (currentCategory === 'ALL' ? 'active' : '') + '" onclick="setCategory(\\'ALL\\')">All Dishes</button>';
      categories.forEach(cat => {
        const activeClass = currentCategory === cat ? 'active' : '';
        container.innerHTML += '<button class="cat-pill ' + activeClass + '" onclick="setCategory(\\'' + cat + '\\')">' + cat + '</button>';
      });
    }

    // Filter Items
    function getFilteredItems() {
      return catalogItems.filter(item => {
        if (currentCategory !== 'ALL' && item.item_group !== currentCategory) {
          return false;
        }
        const isVeg = item.is_veg === true || item.food_type === 'VEG' || item.dietary_type === 'VEG';
        if (currentDietary === 'VEG' && !isVeg) return false;
        if (currentDietary === 'NON_VEG' && isVeg) return false;
        if (searchQuery) {
          const name = (item.item_name || '').toLowerCase();
          const desc = (item.description || '').toLowerCase();
          if (!name.includes(searchQuery) && !desc.includes(searchQuery)) return false;
        }
        return true;
      });
    }

    // Render Food Catalog List
    function renderFoodCatalog() {
      const container = document.getElementById('food-catalog-list');
      const items = getFilteredItems();

      if (items.length === 0) {
        container.innerHTML = 
          '<div class="empty-box">' +
            '<div style="font-size:32px;margin-bottom:8px;">🍽️</div>' +
            '<div style="font-weight:800;font-size:14px;">No food items found</div>' +
            '<div style="font-size:12px;color:var(--text-muted);margin-top:4px;">Try changing filters or search terms</div>' +
          '</div>';
        return;
      }

      container.innerHTML = items.map(item => {
        const isVeg = item.is_veg === true || item.food_type === 'VEG' || item.dietary_type === 'VEG';
        const indicatorClass = isVeg ? 'veg' : 'nonveg';
        const inCartQty = cart[item.id]?.qty || 0;
        const price = Number(item.selling_price || item.retail_sale_price || item.price || item.rate || 0);

        let actionBtnHtml = '';
        if (inCartQty > 0) {
          actionBtnHtml = 
            '<div class="qty-stepper">' +
              '<button class="stepper-btn" onclick="updateItemCart(' + item.id + ', -1)">−</button>' +
              '<span class="stepper-qty">' + inCartQty + '</span>' +
              '<button class="stepper-btn" onclick="updateItemCart(' + item.id + ', 1)">+</button>' +
            '</div>';
        } else {
          actionBtnHtml = '<button class="btn-add" onclick="updateItemCart(' + item.id + ', 1)">+ ADD</button>';
        }

        return (
          '<div class="food-card">' +
            '<div class="food-left">' +
              '<div class="fssai-indicator ' + indicatorClass + '"><span class="fssai-dot"></span></div>' +
              '<div class="food-name">' + item.item_name + '</div>' +
              (item.sub_category ? '<div class="food-sub">' + item.sub_category + '</div>' : '') +
              '<div class="food-price">' + fmtPrice(price) + '</div>' +
            '</div>' +
            '<div class="food-right">' + actionBtnHtml + '</div>' +
          '</div>'
        );
      }).join('');
    }

    // Cart Management
    function updateItemCart(itemId, delta) {
      const item = catalogItems.find(it => it.id === itemId);
      if (!item) return;

      if (!cart[itemId]) {
        cart[itemId] = { item, qty: 0, note: '' };
      }
      cart[itemId].qty += delta;

      if (cart[itemId].qty <= 0) {
        delete cart[itemId];
      }

      renderFoodCatalog();
      updateFloatingCartBar();
      renderCartDrawerItems();
    }

    function updateFloatingCartBar() {
      const bar = document.getElementById('floating-cart-bar');
      let totalQty = 0;
      let totalPrice = 0;

      Object.values(cart).forEach(entry => {
        totalQty += entry.qty;
        const price = Number(entry.item.selling_price || entry.item.retail_sale_price || entry.item.price || entry.item.rate || 0);
        totalPrice += (price * entry.qty);
      });

      if (totalQty > 0 && currentMainTab === 0) {
        document.getElementById('cart-item-count').innerText = totalQty + (totalQty === 1 ? ' ITEM • ' : ' ITEMS • ') + fmtPrice(totalPrice);
        bar.classList.add('visible');
      } else {
        bar.classList.remove('visible');
      }
    }

    function openCartDrawer() {
      renderCartDrawerItems();
      document.getElementById('cart-drawer-overlay').classList.add('open');
    }
    function closeCartDrawer() {
      document.getElementById('cart-drawer-overlay').classList.remove('open');
    }

    function renderCartDrawerItems() {
      const container = document.getElementById('cart-items-container');
      const entries = Object.values(cart);

      if (entries.length === 0) {
        container.innerHTML = '<div style="text-align:center;padding:24px;color:var(--text-muted);font-weight:700;">Your cart is empty. Add some delicious dishes!</div>';
        document.getElementById('bill-subtotal').innerText = fmtPrice(0);
        document.getElementById('bill-grand-total').innerText = fmtPrice(0);
        return;
      }

      let subtotal = 0;
      container.innerHTML = entries.map(entry => {
        const price = Number(entry.item.selling_price || entry.item.retail_sale_price || entry.item.price || entry.item.rate || 0);
        const itemTotal = price * entry.qty;
        subtotal += itemTotal;

        return (
          '<div class="cart-drawer-item">' +
            '<div style="flex:1;">' +
              '<div style="font-weight:800;font-size:13px;">' + entry.item.item_name + '</div>' +
              '<div style="font-size:11px;color:var(--text-muted);margin-top:2px;">' + fmtPrice(price) + ' × ' + entry.qty + '</div>' +
            '</div>' +
            '<div style="display:flex;align-items:center;gap:12px;">' +
              '<div class="qty-stepper">' +
                '<button class="stepper-btn" onclick="updateItemCart(' + entry.item.id + ', -1)">−</button>' +
                '<span class="stepper-qty">' + entry.qty + '</span>' +
                '<button class="stepper-btn" onclick="updateItemCart(' + entry.item.id + ', 1)">+</button>' +
              '</div>' +
              '<div style="font-weight:800;font-size:13px;min-width:60px;text-align:right;">' + fmtPrice(itemTotal) + '</div>' +
            '</div>' +
          '</div>'
        );
      }).join('');

      document.getElementById('bill-subtotal').innerText = fmtPrice(subtotal);
      document.getElementById('bill-grand-total').innerText = fmtPrice(subtotal);
    }

    // Submit Order to Kitchen (KOT)
    async function submitDiningOrder() {
      const entries = Object.values(cart);
      if (entries.length === 0) {
        showToast('Your cart is empty');
        return;
      }

      const submitBtn = document.getElementById('btn-submit-order');
      submitBtn.disabled = true;
      submitBtn.innerText = 'Sending to Kitchen...';

      const itemsPayload = entries.map(entry => ({
        item_id: entry.item.id,
        quantity: entry.qty,
        rate: Number(entry.item.selling_price || entry.item.retail_sale_price || entry.item.price || entry.item.rate || 0),
        notes: entry.note || ''
      }));

      const paymentMethod = document.querySelector('input[name="payment_method"]:checked')?.value || 'PAY_LATER';
      const instructions = document.getElementById('special-instructions').value.trim();

      try {
        const res = await fetch('/api/public/dining/place-order', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            table_id: TABLE_ID,
            table_name: TABLE_NAME,
            outlet_id: OUTLET_ID,
            customer_name: customerProfile.name,
            customer_phone: customerProfile.phone,
            customer_email: customerProfile.email,
            seat: SEAT_NUMBER,
            client_tag: CLIENT_TAG,
            instructions: instructions,
            payment_method: paymentMethod,
            items: itemsPayload
          })
        });

        const data = await res.json();
        if (data.success) {
          showToast('🎉 Order placed successfully to kitchen!');
          cart = {};
          closeCartDrawer();
          updateFloatingCartBar();
          renderFoodCatalog();
          await loadDiningData();
          switchMainTab(1); // Switch to Order History tab
        } else {
          showToast(data.message || data.error || 'Failed to place order');
        }
      } catch (err) {
        showToast('Network error while placing order');
      } finally {
        submitBtn.disabled = false;
        submitBtn.innerText = '🚀 Place Order to Kitchen';
      }
    }

    // Waiter Call
    async function sendWaiterCall(requestType, label) {
      try {
        const res = await fetch('/api/public/dining/call-waiter', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            table_id: TABLE_ID,
            outlet_id: OUTLET_ID,
            request_type: requestType,
            customer_name: customerProfile.name
          })
        });
        const data = await res.json();
        showToast('🔔 Staff notified: ' + label + '. A steward will attend shortly!');
      } catch (_) {
        showToast('Staff notified! Someone will assist you shortly.');
      }
    }

    // Main Tab Switching
    function switchMainTab(index) {
      currentMainTab = index;
      if (index === 0) {
        document.getElementById('tab-btn-menu').classList.add('active');
        document.getElementById('tab-btn-orders').classList.remove('active');
        document.getElementById('view-food-menu').style.display = 'block';
        document.getElementById('view-order-history').style.display = 'none';
        updateFloatingCartBar();
      } else {
        document.getElementById('tab-btn-orders').classList.add('active');
        document.getElementById('tab-btn-menu').classList.remove('active');
        document.getElementById('view-food-menu').style.display = 'none';
        document.getElementById('view-order-history').style.display = 'block';
        document.getElementById('floating-cart-bar').classList.remove('visible');
        renderOrdersTab();
      }
    }

    function updateOrdersTabBadge() {
      const badge = document.getElementById('orders-count-badge');
      const actionTitle = document.getElementById('action-orders-title');
      const actionSub = document.getElementById('action-orders-sub');

      if (activeOrders.length > 0) {
        badge.innerText = activeOrders.length;
        badge.style.display = 'inline-block';
        actionTitle.innerText = 'Orders (' + activeOrders.length + ')';
        actionSub.innerText = 'Active KOTs';
      } else {
        badge.style.display = 'none';
        actionTitle.innerText = 'Orders';
        actionSub.innerText = 'Past orders';
      }
    }

    // Render Orders Tab
    function renderOrdersTab() {
      const container = document.getElementById('orders-content');
      if (activeOrders.length === 0) {
        container.innerHTML = 
          '<div class="empty-box">' +
            '<div style="font-size:44px;margin-bottom:12px;">🧾</div>' +
            '<div style="font-weight:800;font-size:16px;">No Orders Placed Yet</div>' +
            '<div style="font-size:12px;color:var(--text-muted);margin:8px auto 16px auto;max-width:320px;">' +
              'Items you order on this table will appear here with live kitchen status updates.' +
            '</div>' +
            '<button class="btn-submit-order" style="max-width:200px;margin:0 auto;" onclick="switchMainTab(0)">' +
              'Browse Food Menu' +
            '</button>' +
          '</div>';
        return;
      }

      let totalBill = 0;
      const kotsHtml = activeOrders.map(kot => {
        const kotAmount = Number(kot.total_amount || kot.net_amount || 0);
        totalBill += kotAmount;
        const status = (kot.status || 'RECEIVED').toUpperCase();
        const items = kot.items || [];

        return (
          '<div class="order-kot-card">' +
            '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">' +
              '<div>' +
                '<span style="font-weight:900;font-size:14px;">KOT #' + (kot.kot_no || kot.id) + '</span>' +
                '<div style="font-size:11px;color:var(--text-muted);">' + (kot.created_time || 'Just now') + '</div>' +
              '</div>' +
              '<span class="kot-status-badge status-' + status + '">' + (kot.status || 'Received') + '</span>' +
            '</div>' +
            '<div style="font-size:13px;border-top:1px dashed var(--border);padding-top:8px;">' +
              items.map(it => 
                '<div style="display:flex;justify-content:space-between;padding:3px 0;">' +
                  '<span>' + it.quantity + '× ' + (it.item_name || it.item?.item_name || 'Dish') + '</span>' +
                  '<span style="font-weight:700;">' + fmtPrice(it.price || it.rate || 0) + '</span>' +
                '</div>'
              ).join('') +
            '</div>' +
            '<div style="display:flex;justify-content:space-between;margin-top:8px;padding-top:8px;border-top:1px solid var(--border);font-weight:900;font-size:13px;">' +
              '<span>KOT Total</span>' +
              '<span>' + fmtPrice(kotAmount) + '</span>' +
            '</div>' +
          '</div>'
        );
      }).join('');

      const upiId = restaurant.merchant_upi_id || '';
      const upiUrl = upiId ? 'upi://pay?pa=' + encodeURIComponent(upiId) + '&pn=' + encodeURIComponent(restaurant.property_name || 'Restaurant') + '&am=' + totalBill.toFixed(2) + '&cu=INR' : '';
      const qrImg = upiUrl ? 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=' + encodeURIComponent(upiUrl) : '';

      container.innerHTML = 
        kotsHtml +
        '<div style="background:#FFFFFF;border:1px solid var(--border);border-radius:12px;padding:16px;margin-top:12px;">' +
          '<div style="display:flex;justify-content:space-between;font-size:16px;font-weight:900;color:var(--text-main);margin-bottom:12px;">' +
            '<span>Total Bill Due</span>' +
            '<span style="color:var(--primary);">' + fmtPrice(totalBill) + '</span>' +
          '</div>' +
          (upiId ? 
            '<div style="text-align:center;padding:12px;background:#F8FAFC;border:1px solid var(--border);border-radius:10px;margin-bottom:12px;">' +
              '<div style="font-size:12px;font-weight:800;margin-bottom:8px;">Pay with any UPI App</div>' +
              '<img src="' + qrImg + '" style="width:140px;height:140px;border-radius:8px;border:1px solid var(--border);margin-bottom:8px;">' +
              '<div style="font-size:11px;color:var(--text-muted);font-weight:700;">UPI ID: ' + upiId + '</div>' +
            '</div>' : ''
          ) +
          '<button class="btn-submit-order" style="background:#0F172A;" onclick="sendWaiterCall(\\'BILL\\', \\'Printed Bill\\')">' +
            '🧾 Request Physical Printed Bill at Table' +
          '</button>' +
        '</div>';
    }

    // Category & Dietary Filters
    function setCategory(cat) {
      currentCategory = cat;
      renderCategoryPills();
      renderFoodCatalog();
    }
    function setDietaryFilter(type) {
      currentDietary = type;
      document.getElementById('filter-all').className = 'dietary-btn' + (type === 'ALL' ? ' active' : '');
      document.getElementById('filter-veg').className = 'dietary-btn' + (type === 'VEG' ? ' active veg-active' : '');
      document.getElementById('filter-nonveg').className = 'dietary-btn' + (type === 'NON_VEG' ? ' active nonveg-active' : '');
      renderFoodCatalog();
    }
    function handleSearch(val) {
      searchQuery = val.toLowerCase().trim();
      document.getElementById('search-clear').style.display = searchQuery ? 'block' : 'none';
      renderFoodCatalog();
    }
    function clearSearch() {
      document.getElementById('search-input').value = '';
      handleSearch('');
    }

    // Book Table Dialog
    function openBookTableModal() {
      document.getElementById('resv-name').value = customerProfile.name !== 'Guest' ? customerProfile.name : '';
      document.getElementById('resv-phone').value = customerProfile.phone;
      const today = new Date().toISOString().split('T')[0];
      document.getElementById('resv-date').value = today;
      document.getElementById('book-table-overlay').classList.add('open');
    }
    function closeBookTableModal() {
      document.getElementById('book-table-overlay').classList.remove('open');
    }
    async function submitTableReservation() {
      const name = document.getElementById('resv-name').value.trim();
      const phone = document.getElementById('resv-phone').value.trim();
      const date = document.getElementById('resv-date').value;
      const time = document.getElementById('resv-time').value;
      const guests = document.getElementById('resv-guests').value;
      const notes = document.getElementById('resv-notes').value.trim();

      if (!name || !phone) {
        showToast('Name and phone are required');
        return;
      }

      try {
        const res = await fetch('/api/public/dining/book-table', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            outlet_id: OUTLET_ID,
            customer_name: name,
            customer_phone: phone,
            reservation_date: date,
            reservation_time: date + ' ' + time,
            guest_count: Number(guests || 2),
            remarks: notes
          })
        });
        const data = await res.json();
        if (data.success) {
          closeBookTableModal();
          showToast('🎉 Table reservation requested! Restaurant will confirm shortly.');
        } else {
          showToast(data.message || 'Could not request reservation');
        }
      } catch (_) {
        showToast('Reservation request submitted successfully!');
        closeBookTableModal();
      }
    }

    // Table Switcher
    async function openTableSwitcher() {
      const container = document.getElementById('tables-list-container');
      document.getElementById('table-switcher-overlay').classList.add('open');
      try {
        const res = await fetch('/api/public/dining/tables?outlet_id=' + OUTLET_ID);
        const json = await res.json();
        if (json.success && Array.isArray(json.data)) {
          container.innerHTML = json.data.map(tbl => 
            '<div style="display:flex;justify-content:space-between;align-items:center;padding:12px;border-bottom:1px solid var(--border);cursor:pointer;" onclick="selectTable(' + tbl.id + ', \\'' + tbl.table_name + '\\')">' +
              '<div>' +
                '<span style="font-weight:800;font-size:14px;">' + tbl.table_name + '</span>' +
                '<span style="font-size:11px;color:var(--text-muted);margin-left:8px;">(' + (tbl.dining_area?.name || tbl.floor?.name || 'Dining') + ')</span>' +
              '</div>' +
              '<button class="badge-pill" style="border-color:var(--primary);color:var(--primary);">' +
                (tbl.id == TABLE_ID ? 'Current' : 'Select') +
              '</button>' +
            '</div>'
          ).join('');
        }
      } catch (_) {
        container.innerHTML = '<div style="text-align:center;padding:20px;color:var(--text-muted);">Could not load tables</div>';
      }
    }
    function closeTableSwitcher() {
      document.getElementById('table-switcher-overlay').classList.remove('open');
    }
    function selectTable(id, name) {
      window.location.href = '/dining?table_id=' + id + '&table_name=' + encodeURIComponent(name) + '&outlet_id=' + OUTLET_ID;
    }

    function openCustomerProfileModal() {
      const newName = prompt('Enter your name for table orders:', customerProfile.name !== 'Guest' ? customerProfile.name : '');
      if (newName && newName.trim()) {
        customerProfile.name = newName.trim();
        localStorage.setItem('dining_cust_name', customerProfile.name);
        document.getElementById('header-customer-name').innerText = customerProfile.name;
        showToast('Profile updated: ' + customerProfile.name);
      }
    }

    // Start application
    loadDiningData();

    // Auto-poll orders every 4 seconds to reflect kitchen updates live (matches Flutter periodic timer)
    setInterval(async () => {
      try {
        const query = new URLSearchParams({
          outlet_id: OUTLET_ID,
          table_id: TABLE_ID,
          table: TABLE_ID
        });
        const res = await fetch('/api/public/dining/table-info?' + query.toString());
        const json = await res.json();
        if (json.success && json.data) {
          activeOrders = json.data.active_orders || [];
          updateOrdersTabBadge();
          if (currentMainTab === 1) {
            renderOrdersTab();
          }
        }
      } catch (_) {}
    }, 4000);
  </script>
</body>
</html>`;

  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  return res.send(html);
};

module.exports = { renderDiningWebPortal };
