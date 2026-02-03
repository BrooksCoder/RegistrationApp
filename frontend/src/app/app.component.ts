import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { ItemService } from './services/item.service';
import { Item } from './models/item';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule, ReactiveFormsModule],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss']
})
export class AppComponent implements OnInit {
  items: Item[] = [];
  itemForm!: FormGroup;
  loading = false;
  error: string | null = null;
  successMessage: string | null = null;

  constructor(
    private itemService: ItemService,
    private formBuilder: FormBuilder
  ) {
    this.initializeForm();
  }

  ngOnInit(): void {
    this.loadItems();
  }

  private initializeForm(): void {
    this.itemForm = this.formBuilder.group({
      name: ['', [Validators.required, Validators.minLength(3)]],
      description: ['', [Validators.required, Validators.minLength(5)]]
    });
  }

  loadItems(): void {
    this.loading = true;
    this.error = null;
    
    this.itemService.getItems().subscribe({
      next: (data) => {
        this.items = data;
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

    const newItem = {
      name: this.itemForm.value.name,
      description: this.itemForm.value.description
    };

    this.itemService.addItem(newItem).subscribe({
      next: (item) => {
        this.items.push(item);
        this.itemForm.reset();
        this.successMessage = 'Item added successfully!';
        this.loading = false;
        
        // Clear success message after 3 seconds
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
}
