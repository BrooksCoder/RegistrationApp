import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ItemService } from './services/item.service';
import { Item } from './models/item';

// Interfaces for new features
interface AuditLog {
  id: string;
  itemId: number;
  action: string;
  details: string;
  changedBy: string;
  timestamp: Date;
}

interface Notification {
  id: string;
  subject: string;
  recipientEmail: string;
  status: 'Pending' | 'Sent' | 'Failed';
  timestamp: Date;
}

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule, ReactiveFormsModule],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements OnInit {
  // Tab Management
  activeTab: 'items' | 'audit' | 'notifications' | 'approvals' | 'analytics' = 'items';

  // Items Management
  items: Item[] = [];
  itemForm!: FormGroup;
  loading = false;
  error: string | null = null;
  successMessage: string | null = null;

  // File Upload
  selectedFile: File | null = null;
  imagePreviewUrl: string | null = null;
  isDragging = false;

  // Audit Log
  auditLogs: AuditLog[] = [];
  loadingAudit = false;

  // Notifications
  notifications: Notification[] = [];
  queuedNotifications = 0;
  sentNotifications = 0;
  failedNotifications = 0;

  // Approvals
  pendingItems: Item[] = [];
  pendingApprovals = 0;
  approvedCount = 0;
  rejectedCount = 0;

  // Analytics
  totalItems = 0;
  storageUsed = 0; // bytes
  queueDepth = 0;
  auditCount = 0;
  apiResponseTime = 150;
  successRate = 99.8;

  constructor(
    private itemService: ItemService,
    private formBuilder: FormBuilder
  ) {
    this.initializeForm();
  }

  ngOnInit(): void {
    this.loadItems();
    this.loadAuditLogs();
    this.loadNotifications();
    this.loadApprovals();
    this.loadAnalytics();
    this.setupAutoRefresh();
  }

  private initializeForm(): void {
    this.itemForm = this.formBuilder.group({
      name: ['', [Validators.required, Validators.minLength(3)]],
      description: ['', [Validators.required, Validators.minLength(5)]]
    });
  }

  // ============= ITEMS MANAGEMENT =============

  loadItems(): void {
    this.loading = true;
    this.error = null;
    
    this.itemService.getItems().subscribe({
      next: (data) => {
        this.items = data;
        this.totalItems = data.length;
        this.loading = false;
      },
      error: (err) => {
        this.error = 'Failed to load items. Please try again later.';
        console.error('Error loading items:', err);
        this.loading = false;
      }
    });
  }

  addItem(): void {
    if (this.itemForm.invalid) {
      this.error = 'Please fill in all required fields correctly.';
      return;
    }

    this.loading = true;
    this.error = null;
    this.successMessage = null;

    const formData = new FormData();
    formData.append('name', this.itemForm.value.name);
    formData.append('description', this.itemForm.value.description);
    
    if (this.selectedFile) {
      formData.append('image', this.selectedFile, this.selectedFile.name);
    }

    this.itemService.addItemWithImage(formData).subscribe({
      next: (item) => {
        this.items.push(item);
        this.itemForm.reset();
        this.selectedFile = null;
        this.imagePreviewUrl = null;
        this.successMessage = 'Item added successfully!';
        this.loading = false;
        
        setTimeout(() => {
          this.successMessage = null;
        }, 3000);
      },
      error: (err) => {
        this.error = 'Failed to add item. Please try again.';
        console.error('Error adding item:', err);
        this.loading = false;
      }
    });
  }

  deleteItem(id: number): void {
    if (!confirm('Are you sure you want to delete this item?')) {
      return;
    }

    this.itemService.deleteItem(id).subscribe({
      next: () => {
        this.items = this.items.filter(item => item.id !== id);
        this.successMessage = 'Item deleted successfully!';
        this.totalItems = this.items.length;
        
        setTimeout(() => {
          this.successMessage = null;
        }, 3000);
      },
      error: (err) => {
        this.error = 'Failed to delete item. Please try again.';
        console.error('Error deleting item:', err);
      }
    });
  }

  // ============= FILE UPLOAD =============

  onFileSelected(event: any): void {
    const file = event.target.files[0];
    if (file) {
      this.processFile(file);
    }
  }

  onDragOver(event: DragEvent): void {
    event.preventDefault();
    this.isDragging = true;
  }

  onDragLeave(event: DragEvent): void {
    event.preventDefault();
    this.isDragging = false;
  }

  onFileDrop(event: DragEvent): void {
    event.preventDefault();
    this.isDragging = false;
    
    const files = event.dataTransfer?.files;
    if (files && files.length > 0) {
      this.processFile(files[0]);
    }
  }

  private processFile(file: File): void {
    if (!file.type.startsWith('image/')) {
      this.error = 'Please select an image file';
      return;
    }

    if (file.size > 5 * 1024 * 1024) {
      this.error = 'Image size must be less than 5MB';
      return;
    }

    this.selectedFile = file;
    
    // Create preview
    const reader = new FileReader();
    reader.onload = (e) => {
      this.imagePreviewUrl = e.target?.result as string;
    };
    reader.readAsDataURL(file);
  }

  downloadImage(itemId: number): void {
    const item = this.items.find(i => i.id === itemId);
    if (item && item.imageUrl) {
      window.open(item.imageUrl, '_blank');
    }
  }

  // ============= AUDIT LOG =============

  loadAuditLogs(): void {
    this.loadingAudit = true;
    this.itemService.getAuditLogs().subscribe({
      next: (logs) => {
        this.auditLogs = logs;
        this.auditCount = logs.length;
        this.loadingAudit = false;
      },
      error: (err) => {
        console.error('Error loading audit logs:', err);
        this.loadingAudit = false;
        // Generate mock data if API fails
        this.generateMockAuditLogs();
      }
    });
  }

  viewAuditLog(itemId: number): void {
    this.activeTab = 'audit';
  }

  getAuditIcon(action: string): string {
    const icons: { [key: string]: string } = {
      'CREATE': '➕',
      'UPDATE': '✏️',
      'DELETE': '🗑️',
      'UPLOAD': '📸',
      'DOWNLOAD': '⬇️',
      'APPROVE': '✅',
      'REJECT': '❌'
    };
    return icons[action] || '📝';
  }

  private generateMockAuditLogs(): void {
    this.auditLogs = [
      {
        id: '1',
        itemId: 1,
        action: 'CREATE',
        details: 'Item created in the system',
        changedBy: 'System',
        timestamp: new Date()
      },
      {
        id: '2',
        itemId: 1,
        action: 'UPLOAD',
        details: 'Image uploaded for item',
        changedBy: 'User Admin',
        timestamp: new Date(Date.now() - 3600000)
      }
    ];
  }

  // ============= NOTIFICATIONS =============

  loadNotifications(): void {
    this.itemService.getNotifications().subscribe({
      next: (notifs) => {
        this.notifications = notifs;
        this.queuedNotifications = notifs.filter(n => n.status === 'Pending').length;
        this.sentNotifications = notifs.filter(n => n.status === 'Sent').length;
        this.failedNotifications = notifs.filter(n => n.status === 'Failed').length;
      },
      error: (err) => {
        console.error('Error loading notifications:', err);
        this.generateMockNotifications();
      }
    });
  }

  private generateMockNotifications(): void {
    this.notifications = [
      {
        id: '1',
        subject: 'Item Created Notification',
        recipientEmail: 'admin@example.com',
        status: 'Sent',
        timestamp: new Date()
      },
      {
        id: '2',
        subject: 'Approval Required',
        recipientEmail: 'reviewer@example.com',
        status: 'Pending',
        timestamp: new Date()
      }
    ];
    this.queuedNotifications = 1;
    this.sentNotifications = 1;
    this.failedNotifications = 0;
  }

  // ============= APPROVALS =============

  loadApprovals(): void {
    this.itemService.getPendingApprovals().subscribe({
      next: (items) => {
        this.pendingItems = items;
        this.pendingApprovals = items.length;
        this.approvedCount = this.items.filter(i => i.status === 'Approved').length;
        this.rejectedCount = this.items.filter(i => i.status === 'Rejected').length;
      },
      error: (err) => {
        console.error('Error loading approvals:', err);
        this.pendingApprovals = this.items.filter(i => !i.status || i.status === 'Pending').length;
        this.pendingItems = this.items.filter(i => !i.status || i.status === 'Pending');
      }
    });
  }

  approveItem(id: number): void {
    this.itemService.approveItem(id).subscribe({
      next: () => {
        const item = this.items.find(i => i.id === id);
        if (item) {
          item.status = 'Approved';
        }
        this.successMessage = 'Item approved successfully!';
        this.loadApprovals();
        this.loadAuditLogs();
        
        setTimeout(() => {
          this.successMessage = null;
        }, 3000);
      },
      error: (err) => {
        this.error = 'Failed to approve item.';
        console.error('Error approving item:', err);
      }
    });
  }

  rejectItem(id: number): void {
    this.itemService.rejectItem(id).subscribe({
      next: () => {
        const item = this.items.find(i => i.id === id);
        if (item) {
          item.status = 'Rejected';
        }
        this.successMessage = 'Item rejected successfully!';
        this.loadApprovals();
        this.loadAuditLogs();
        
        setTimeout(() => {
          this.successMessage = null;
        }, 3000);
      },
      error: (err) => {
        this.error = 'Failed to reject item.';
        console.error('Error rejecting item:', err);
      }
    });
  }

  // ============= ANALYTICS =============

  loadAnalytics(): void {
    this.itemService.getAnalytics().subscribe({
      next: (analytics) => {
        this.totalItems = analytics.totalItems;
        this.storageUsed = analytics.storageUsed;
        this.queueDepth = analytics.queueDepth;
        this.auditCount = analytics.auditCount;
        this.apiResponseTime = analytics.apiResponseTime;
        this.successRate = analytics.successRate;
      },
      error: (err) => {
        console.error('Error loading analytics:', err);
      }
    });
  }

  // ============= AUTO REFRESH =============

  private setupAutoRefresh(): void {
    // Refresh data every 30 seconds
    setInterval(() => {
      if (this.activeTab === 'items') {
        this.loadItems();
      } else if (this.activeTab === 'audit') {
        this.loadAuditLogs();
      } else if (this.activeTab === 'notifications') {
        this.loadNotifications();
      } else if (this.activeTab === 'approvals') {
        this.loadApprovals();
      } else if (this.activeTab === 'analytics') {
        this.loadAnalytics();
      }
    }, 30000);
  }
}
