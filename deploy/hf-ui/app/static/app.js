const state = {
  type: "models",
  items: [],
  selected: null,
  authenticated: false,
  previewRequestId: 0,
  uploadXhr: null,
};

const PREVIEW_EXTENSIONS = [".jsonl", ".json", ".csv", ".parquet"];
const PREVIEW_METADATA_FILES = new Set(["dataset_info.json"]);

const els = {
  list: document.querySelector("#list"),
  search: document.querySelector("#search"),
  tabModels: document.querySelector("#tab-models"),
  tabDatasets: document.querySelector("#tab-datasets"),
  empty: document.querySelector("#empty"),
  detail: document.querySelector("#detail"),
  userStatus: document.querySelector("#user-status"),
  loginLink: document.querySelector("#login-link"),
  logoutLink: document.querySelector("#logout-link"),
  kind: document.querySelector("#detail-kind"),
  title: document.querySelector("#detail-title"),
  summary: document.querySelector("#detail-summary"),
  tags: document.querySelector("#detail-tags"),
  owner: document.querySelector("#detail-owner"),
  version: document.querySelector("#detail-version"),
  license: document.querySelector("#detail-license"),
  storage: document.querySelector("#detail-storage"),
  readme: document.querySelector("#readme"),
  files: document.querySelector("#files"),
  uploadForm: document.querySelector("#upload-form"),
  uploadFile: document.querySelector("#upload-file"),
  uploadPath: document.querySelector("#upload-path"),
  uploadOverwrite: document.querySelector("#upload-overwrite"),
  uploadSubmit: document.querySelector("#upload-submit"),
  uploadProgress: document.querySelector("#upload-progress"),
  uploadStatus: document.querySelector("#upload-status"),
  previewSection: document.querySelector("#preview-section"),
  previewFiles: document.querySelector("#preview-files"),
  previewMeta: document.querySelector("#preview-meta"),
  previewWarnings: document.querySelector("#preview-warnings"),
  previewData: document.querySelector("#preview-data"),
};

function escapeHtml(value) {
  return String(value == null ? "" : value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function renderMarkdown(source) {
  const lines = String(source || "").split("\n");
  let html = "";
  let inCode = false;
  for (const line of lines) {
    if (line.startsWith("```")) {
      html += inCode ? "</code></pre>" : "<pre><code>";
      inCode = !inCode;
      continue;
    }
    if (inCode) {
      html += `${escapeHtml(line)}\n`;
      continue;
    }
    if (line.startsWith("# ")) {
      html += `<h2>${escapeHtml(line.slice(2))}</h2>`;
    } else if (line.startsWith("## ")) {
      html += `<h3>${escapeHtml(line.slice(3))}</h3>`;
    } else if (line.startsWith("- ")) {
      html += `<p>• ${escapeHtml(line.slice(2))}</p>`;
    } else if (line.trim()) {
      html += `<p>${escapeHtml(line)}</p>`;
    }
  }
  if (inCode) html += "</code></pre>";
  return html || "<p>No README found.</p>";
}

function formatBytes(bytes) {
  if (!Number.isFinite(bytes)) return "";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let value = bytes;
  let index = 0;
  while (value >= 1024 && index < units.length - 1) {
    value /= 1024;
    index += 1;
  }
  return `${value.toFixed(index === 0 ? 0 : 1)} ${units[index]}`;
}

function formatNumber(value) {
  if (!Number.isFinite(Number(value))) return "";
  return Number(value).toLocaleString();
}

async function api(path, options = {}) {
  const response = await fetch(path, { credentials: "include", ...options });
  if (!response.ok) {
    const detail = await readErrorDetail(response);
    const message = response.status === 401 ? "Sign in required" : `Request failed (${response.status})`;
    const error = new Error(message);
    error.status = response.status;
    error.detail = detail;
    throw error;
  }
  return response.json();
}

async function readErrorDetail(response) {
  const text = await response.text().catch(() => "");
  if (!text) return "";
  try {
    const data = JSON.parse(text);
    const detail = data.detail || data.error || data.message;
    if (typeof detail === "string") return detail;
    if (detail == null) return text;
    return JSON.stringify(detail);
  } catch {
    return text;
  }
}

async function loadSession() {
  const data = await api("/api/auth/me");
  state.authenticated = data.authenticated;
  if (data.authenticated) {
    els.userStatus.textContent = data.user.name || "Signed in";
    els.loginLink.hidden = true;
    els.logoutLink.hidden = false;
  } else {
    els.userStatus.textContent = "Not signed in";
    els.loginLink.hidden = false;
    els.logoutLink.hidden = true;
  }
}

async function loadList() {
  els.list.innerHTML = '<div class="item"><strong>Loading</strong><span>Reading catalog</span></div>';
  try {
    const params = new URLSearchParams();
    if (els.search.value.trim()) params.set("q", els.search.value.trim());
    const data = await api(`/api/${state.type}?${params.toString()}`);
    state.items = data.items || [];
    renderList();
  } catch (error) {
    els.list.innerHTML = `<div class="item"><strong>${escapeHtml(error.message)}</strong><span>Use the sign-in button if needed.</span></div>`;
  }
}

function renderList() {
  if (!state.items.length) {
    els.list.innerHTML = '<div class="item"><strong>No entries</strong><span>Try a different search.</span></div>';
    return;
  }
  els.list.innerHTML = state.items
    .map((item) => {
      const id = `${item.kind}:${item.owner}/${item.name}`;
      const active = state.selected && id === `${state.selected.kind}:${state.selected.owner}/${state.selected.name}`;
      return `<button class="item ${active ? "active" : ""}" type="button" data-id="${escapeHtml(id)}">
        <strong>${escapeHtml(item.title || item.name)}</strong>
        <span>${escapeHtml(item.owner)}/${escapeHtml(item.name)} · ${escapeHtml((item.tags || []).join(", "))}</span>
      </button>`;
    })
    .join("");
}

async function selectItem(id) {
  const [kind, rest] = id.split(":");
  const [owner, name] = rest.split("/");
  const { data, files } = await loadItemDetail(kind, owner, name);
  state.selected = data.item;
  els.empty.hidden = true;
  els.detail.hidden = false;
  renderList();
  renderDetail(data.item, data.readme, files.items || []);
}

async function loadItemDetail(kind, owner, name) {
  const encodedOwner = encodeURIComponent(owner);
  const encodedName = encodeURIComponent(name);
  const data = await api(`/api/${kind}/${encodedOwner}/${encodedName}`);
  const files = await api(`/api/${kind}/${encodedOwner}/${encodedName}/files`);
  return { data, files };
}

async function refreshSelectedDetail() {
  if (!state.selected) return;
  const { data, files } = await loadItemDetail(state.selected.kind, state.selected.owner, state.selected.name);
  state.selected = data.item;
  renderDetail(data.item, data.readme, files.items || []);
}

function renderDetail(item, readme, files) {
  els.kind.textContent = item.kind;
  els.title.textContent = item.title || item.name;
  els.summary.textContent = item.summary || "";
  els.tags.innerHTML = (item.tags || []).map((tag) => `<span class="tag">${escapeHtml(tag)}</span>`).join("");
  els.owner.textContent = item.owner || "";
  els.version.textContent = item.version || "";
  els.license.textContent = item.license || "";
  els.storage.textContent = `${item.bucket}/${item.prefix}`;
  els.readme.innerHTML = renderMarkdown(readme);
  els.files.innerHTML = files.length
    ? files.map((file) => fileRow(item, file)).join("")
    : "<p>No files found for this prefix.</p>";
  resetUploadForm();
  renderPreviewSection(item, files);
}

function fileRow(item, file) {
  return `<div class="file-row">
    <div class="file-path">${escapeHtml(file.path)}</div>
    <div class="file-size">${formatBytes(file.size)}</div>
    <div class="file-time">${escapeHtml(file.last_modified || "")}</div>
    <button type="button" data-download="${escapeHtml(file.path)}" data-kind="${escapeHtml(item.kind)}" data-owner="${escapeHtml(item.owner)}" data-name="${escapeHtml(item.name)}">Download</button>
  </div>`;
}

async function downloadFile(button) {
  const params = new URLSearchParams({
    kind: button.dataset.kind,
    owner: button.dataset.owner,
    name: button.dataset.name,
    path: button.dataset.download,
  });
  const data = await api(`/api/files/presign?${params.toString()}`, { method: "POST" });
  window.location.href = data.url;
}

function resetUploadForm() {
  if (state.uploadXhr) {
    state.uploadXhr.abort();
    state.uploadXhr = null;
  }
  els.uploadForm.reset();
  els.uploadProgress.hidden = true;
  els.uploadProgress.value = 0;
  els.uploadStatus.textContent = "";
  els.uploadSubmit.disabled = false;
}

function setUploadStatus(message, type = "") {
  els.uploadStatus.textContent = message;
  els.uploadStatus.className = type ? `upload-status ${type}` : "upload-status";
}

function selectedPresignKind() {
  return state.selected.kind === "dataset" ? "dataset" : "model";
}

function uploadPut(url, file, headers = {}) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    state.uploadXhr = xhr;
    xhr.open("PUT", url);
    for (const [name, value] of Object.entries(headers || {})) {
      if (value != null && value !== "") xhr.setRequestHeader(name, value);
    }
    xhr.upload.addEventListener("progress", (event) => {
      if (!event.lengthComputable) {
        els.uploadProgress.hidden = false;
        setUploadStatus(`Uploading ${file.name}`);
        return;
      }
      const percent = Math.max(0, Math.min(100, Math.round((event.loaded / event.total) * 100)));
      els.uploadProgress.hidden = false;
      els.uploadProgress.value = percent;
      setUploadStatus(`Uploading ${percent}%`);
    });
    xhr.addEventListener("load", () => {
      state.uploadXhr = null;
      if (xhr.status >= 200 && xhr.status < 300) {
        resolve();
        return;
      }
      const detail = xhr.responseText ? ` ${xhr.responseText}` : "";
      reject(new Error(`Upload PUT failed (${xhr.status}).${detail}`));
    });
    xhr.addEventListener("error", () => {
      state.uploadXhr = null;
      reject(new Error("Upload PUT failed. Check the storage endpoint and try again."));
    });
    xhr.addEventListener("abort", () => {
      state.uploadXhr = null;
      reject(new Error("Upload canceled."));
    });
    xhr.send(file);
  });
}

function uploadErrorMessage(error) {
  const detail = String(error.detail || "");
  if (error.status === 409 && detail.includes("object_exists")) {
    return "A file already exists at that path. Enable overwrite to replace it.";
  }
  if (error.status === 409) {
    return detail || "A file already exists at that path. Enable overwrite to replace it.";
  }
  return detail ? `${error.message}: ${detail}` : error.message;
}

async function uploadSelectedFile() {
  const file = els.uploadFile.files[0];
  const path = els.uploadPath.value.trim();
  if (!state.selected) return;
  if (!file) {
    setUploadStatus("Choose a file to upload.", "error");
    return;
  }
  if (!path) {
    setUploadStatus("Enter a target path.", "error");
    return;
  }

  els.uploadSubmit.disabled = true;
  els.uploadProgress.hidden = false;
  els.uploadProgress.value = 0;
  setUploadStatus("Requesting upload URL");

  try {
    const params = new URLSearchParams({
      action: "upload",
      kind: selectedPresignKind(),
      owner: state.selected.owner,
      name: state.selected.name,
      path,
      overwrite: els.uploadOverwrite.checked ? "true" : "false",
    });
    const data = await api(`/api/files/presign?${params.toString()}`, { method: "POST" });
    if (!data.url) throw new Error("Upload URL was not returned.");
    await uploadPut(data.url, file, data.headers || {});
    els.uploadProgress.value = 100;
    setUploadStatus("Upload complete. Refreshing files.", "success");
    await refreshSelectedDetail();
    setUploadStatus(`Uploaded ${path}`, "success");
  } catch (error) {
    setUploadStatus(uploadErrorMessage(error), "error");
  } finally {
    els.uploadSubmit.disabled = false;
  }
}

function isPreviewFile(file) {
  const path = String(file.path || "");
  const base = path.split("/").pop().toLowerCase();
  return !PREVIEW_METADATA_FILES.has(base) && PREVIEW_EXTENSIONS.some((extension) => path.toLowerCase().endsWith(extension));
}

function splitLabel(path) {
  const base = String(path || "").split("/").pop() || path;
  for (const extension of PREVIEW_EXTENSIONS) {
    if (base.toLowerCase().endsWith(extension)) {
      return base.slice(0, -extension.length);
    }
  }
  return base;
}

function renderPreviewSection(item, files) {
  state.previewRequestId += 1;
  els.previewSection.hidden = true;
  els.previewFiles.innerHTML = "";
  els.previewMeta.textContent = "";
  els.previewWarnings.innerHTML = "";
  els.previewData.innerHTML = "";

  if (item.kind !== "dataset") return;

  const previewFiles = files.filter(isPreviewFile);
  if (!previewFiles.length) return;

  els.previewSection.hidden = false;
  els.previewFiles.innerHTML = previewFiles
    .map((file, index) => {
      const active = index === 0 ? "active" : "";
      return `<button class="preview-file ${active}" type="button" data-preview-path="${escapeHtml(file.path)}">
        <strong>${escapeHtml(splitLabel(file.path))}</strong>
        <span>${escapeHtml(file.path)}</span>
      </button>`;
    })
    .join("");
  loadPreview(previewFiles[0].path);
}

async function loadPreview(path) {
  if (!state.selected || state.selected.kind !== "dataset") return;
  const requestId = ++state.previewRequestId;
  const params = new URLSearchParams({ path });
  els.previewData.innerHTML = '<div class="preview-panel"><strong>Loading preview</strong></div>';
  els.previewMeta.textContent = "";
  els.previewWarnings.innerHTML = "";
  try {
    const data = await api(
      `/api/dataset/${encodeURIComponent(state.selected.owner)}/${encodeURIComponent(state.selected.name)}/preview?${params.toString()}`,
    );
    if (requestId !== state.previewRequestId) return;
    renderPreview(data);
  } catch (error) {
    if (requestId !== state.previewRequestId) return;
    renderPreviewError(error);
  }
}

function renderPreviewError(error) {
  const detail = error.detail ? `<p>${escapeHtml(error.detail)}</p>` : "";
  els.previewMeta.textContent = "";
  els.previewWarnings.innerHTML = "";
  els.previewData.innerHTML = `<div class="preview-panel preview-panel-wide preview-error">
    <strong>${escapeHtml(error.message || "Preview failed")}</strong>
    ${detail}
  </div>`;
}

function renderPreview(data) {
  const file = data.file || {};
  els.previewMeta.textContent = `${formatNumber(file.sampled_rows)} sampled rows · ${formatNumber(file.returned_rows)} shown · ${formatBytes(file.max_bytes)} byte cap`;
  els.previewWarnings.innerHTML = (data.warnings || []).length
    ? data.warnings.map((warning) => `<div>${escapeHtml(warning)}</div>`).join("")
    : "";
  els.previewData.innerHTML = [
    renderSchemaPanel(data.schema || []),
    renderRowsPanel(data.schema || [], data.rows || []),
    renderStatsPanel(data.stats || []),
  ].join("");
}

function renderSchemaPanel(schema) {
  if (!schema.length) {
    return '<div class="preview-panel"><h4>Schema</h4><p>No columns found.</p></div>';
  }
  const hasSourceType = schema.some((column) => Object.prototype.hasOwnProperty.call(column, "source_type"));
  const sourceTypeHead = hasSourceType ? "<th>Source type</th>" : "";
  const rows = schema
    .map(
      (column) => `<tr>
        <td>${escapeHtml(column.name)}</td>
        <td>${escapeHtml(column.type)}</td>
        ${hasSourceType ? `<td>${escapeHtml(column.source_type)}</td>` : ""}
        <td>${formatNumber(column.non_null)}</td>
        <td>${formatNumber(column.missing)}</td>
      </tr>`,
    )
    .join("");
  return `<div class="preview-panel">
    <h4>Schema</h4>
    <div class="table-scroll">
      <table>
        <thead><tr><th>Column</th><th>Type</th>${sourceTypeHead}<th>Non-null</th><th>Missing</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  </div>`;
}

function renderRowsPanel(schema, rows) {
  const columns = schema.map((column) => column.name);
  if (!columns.length || !rows.length) {
    return '<div class="preview-panel preview-panel-wide"><h4>Sample Rows</h4><p>No rows found.</p></div>';
  }
  const head = columns.map((column) => `<th>${escapeHtml(column)}</th>`).join("");
  const body = rows
    .map((row) => `<tr>${columns.map((column) => `<td>${escapeHtml(row[column])}</td>`).join("")}</tr>`)
    .join("");
  return `<div class="preview-panel preview-panel-wide">
    <h4>Sample Rows</h4>
    <div class="table-scroll sample-scroll">
      <table>
        <thead><tr>${head}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  </div>`;
}

function renderStatsPanel(stats) {
  if (!stats.length) {
    return '<div class="preview-panel preview-panel-wide"><h4>Column Stats</h4><p>No stats available.</p></div>';
  }
  return `<div class="preview-panel preview-panel-wide">
    <h4>Column Stats</h4>
    <div class="stats-grid">${stats.map(renderStatCard).join("")}</div>
  </div>`;
}

function renderStatCard(stat) {
  return `<div class="stat-card">
    <div class="stat-head">
      <strong>${escapeHtml(stat.column)}</strong>
      <span>${escapeHtml(stat.kind)} · ${escapeHtml(stat.type)}</span>
    </div>
    ${renderStatBody(stat)}
  </div>`;
}

function renderStatBody(stat) {
  if (stat.kind === "numeric") {
    return renderMetricTable([
      ["count", stat.count],
      ["missing", stat.missing],
      ["min", stat.min],
      ["max", stat.max],
      ["mean", stat.mean],
      ["stddev", stat.stddev],
      ["p50", stat.p50],
      ["p90", stat.p90],
    ]);
  }
  if (stat.kind === "text_length") {
    const length = stat.length || {};
    return `${renderMetricTable([
      ["count", stat.count],
      ["missing", stat.missing],
      ["min length", length.min],
      ["max length", length.max],
      ["mean length", length.mean],
      ["p50 length", length.p50],
      ["p90 length", length.p90],
      ["p95 length", length.p95],
    ])}${renderBuckets(stat.buckets || [])}`;
  }
  if (stat.kind === "categorical" || stat.kind === "mixed") {
    return `${renderMetricTable([
      ["count", stat.count],
      ["missing", stat.missing],
      ["unique", stat.unique_count],
    ])}${renderTopCounts(stat.top_counts || [])}`;
  }
  return renderMetricTable([
    ["count", stat.count],
    ["missing", stat.missing],
  ]);
}

function renderMetricTable(rows) {
  return `<table class="metric-table"><tbody>${rows
    .map(([label, value]) => `<tr><th>${escapeHtml(label)}</th><td>${escapeHtml(value)}</td></tr>`)
    .join("")}</tbody></table>`;
}

function renderTopCounts(counts) {
  if (!counts.length) return "";
  return `<div class="count-list">${counts
    .map((item) => `<div><span>${escapeHtml(item.value)}</span><strong>${formatNumber(item.count)}</strong></div>`)
    .join("")}</div>`;
}

function renderBuckets(buckets) {
  if (!buckets.length) return "";
  const max = Math.max(1, ...buckets.map((bucket) => Number(bucket.count) || 0));
  return `<div class="bucket-list">${buckets
    .map((bucket) => {
      const width = Math.round(((Number(bucket.count) || 0) / max) * 100);
      return `<div class="bucket-row">
        <span>${escapeHtml(bucket.label)}</span>
        <div><i style="width: ${width}%"></i></div>
        <strong>${formatNumber(bucket.count)}</strong>
      </div>`;
    })
    .join("")}</div>`;
}

els.tabModels.addEventListener("click", () => {
  state.type = "models";
  els.tabModels.classList.add("active");
  els.tabDatasets.classList.remove("active");
  loadList();
});

els.tabDatasets.addEventListener("click", () => {
  state.type = "datasets";
  els.tabDatasets.classList.add("active");
  els.tabModels.classList.remove("active");
  loadList();
});

els.search.addEventListener("input", () => {
  window.clearTimeout(els.search._timer);
  els.search._timer = window.setTimeout(loadList, 180);
});

els.list.addEventListener("click", (event) => {
  const button = event.target.closest("[data-id]");
  if (button) selectItem(button.dataset.id).catch((error) => alert(error.message));
});

els.files.addEventListener("click", (event) => {
  const button = event.target.closest("[data-download]");
  if (button) downloadFile(button).catch((error) => alert(error.message));
});

els.uploadFile.addEventListener("change", () => {
  const file = els.uploadFile.files[0];
  els.uploadPath.value = file ? file.name : "";
  els.uploadProgress.hidden = true;
  els.uploadProgress.value = 0;
  setUploadStatus("");
});

els.uploadForm.addEventListener("submit", (event) => {
  event.preventDefault();
  uploadSelectedFile();
});

els.previewFiles.addEventListener("click", (event) => {
  const button = event.target.closest("[data-preview-path]");
  if (!button) return;
  els.previewFiles.querySelectorAll(".preview-file").forEach((item) => item.classList.toggle("active", item === button));
  loadPreview(button.dataset.previewPath);
});

loadSession().finally(loadList);
